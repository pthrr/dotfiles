/**
 * Serialize hook events into one versioned proposal and exact human consent.
 * The hooks authorize operations; they do not sandbox what an approved program
 * does, and cancelling a running mutation is best effort and undoes nothing.
 *
 * The input is the neutral event of ../event.ts. A client without turn ids
 * sends none, and the turn checks then have nothing to compare.
 */
import { spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import {
    chmodSync,
    closeSync,
    existsSync,
    mkdirSync,
    openSync,
    readFileSync,
    renameSync,
    rmSync,
    statSync,
    writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { canonicalPath, context, fullPath, succeeded, toolEffect, unique } from "../event.ts";
import type { Effect, HookInput } from "../event.ts";

type Snapshot = { path: string; hash: string; identity: string };
type Proposal = Snapshot & { id: string; shown: boolean; approved: boolean };
type State = {
    protocol: 3;
    humanId: string | null;
    prompt: string;
    turnId: string | null;
    proposal: Proposal | null;
    plansWritten: string[];
    inFlight: string[];
    stopFeedback?: string;
};
type GateRecord = {
    ambiguous?: boolean;
    plan_written?: string;
    governed_by?: string;
    presented?: string;
    hash?: string;
};
const entrypoint = fileURLToPath(import.meta.url);
const directory = dirname(entrypoint);
const freshState = (): State => ({
    protocol: 3,
    humanId: null,
    prompt: "",
    turnId: null,
    proposal: null,
    plansWritten: [],
    inFlight: [],
});
let currentEvent: string | undefined;
let freePlanWrite = false;

// Harness config, memory and state, plus /tmp and ~/tmp, are exempt, and so is
// PLAN.md anywhere. Only declared file targets qualify; a shell working directory
// is never a target. A dotfile directly in $HOME cannot be covered: that would mean
// exempting $HOME, which would ungate every non-repo tree under it. Home Manager's
// links are read-only; edit their sources in the dotfiles repo.
function exemptPath(path: string): boolean {
    const userHome = canonicalPath(homedir());
    const roots = [".claude", ".codex", ".agents", ".config/opencode", ".local/share/opencode", "tmp"].map(
        (directory) => join(userHome, directory),
    );
    roots.push("/tmp");
    return basename(path) === "PLAN.md" || roots.some((directory) => path.startsWith(`${directory}/`));
}

// A write under an exempt tree needs neither state nor write-gate.sh, which keeps
// no list of its own. A PLAN.md still goes through: the gate records it as written.
function ungated(path: string): boolean {
    return basename(path) !== "PLAN.md" && exemptPath(path);
}

// Arbitrary programs have unknowable write sets, so write-gate.sh judges a
// mutating shell command as one pseudo-file in its working directory.
function gateEffect(input: HookInput): Effect {
    const effect = toolEffect(input);

    if (!effect.shell || effect.readonly) {
        return effect;
    }

    const args = input.tool_input ?? {};
    return { ...effect, paths: [fullPath(".shell-command", fullPath(args.workdir ?? input.cwd, input.cwd))] };
}

function snapshot(path: string): Snapshot | null {
    try {
        const resolved = canonicalPath(path);
        const content = readFileSync(resolved);
        const info = statSync(resolved, { bigint: true });
        return {
            path: resolved,
            hash: createHash("sha256").update(content).digest("hex"),
            // File identity catches deletion/recreation and edits restored to the
            // same bytes. Re-presenting a file changes none of these fields.
            identity: `${info.dev}:${info.ino}:${info.ctimeNs}`,
        };
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code === "ENOENT") {
            return null;
        }

        throw error;
    }
}

function sameVersion(left: Snapshot, right: Snapshot): boolean {
    return left.path === right.path && left.hash === right.hash && left.identity === right.identity;
}

function proposalFor(value: Snapshot): Proposal {
    return { ...value, id: randomUUID(), shown: false, approved: false };
}

function reconcile(state: State): void {
    if (!state.proposal) {
        return;
    }

    const current = snapshot(state.proposal.path);

    if (!current) {
        // Closing discards authority, including the presentation record. An
        // identical file created later can only acquire a fresh proposal ID.
        state.proposal = null;
    } else if (!sameVersion(state.proposal, current)) {
        state.proposal = proposalFor(current);
    }
}

function gate(mode: "pre-write" | "stop", input: HookInput, state: State, fields: Record<string, unknown> = {}) {
    const result = spawnSync("bash", [join(directory, "write-gate.sh"), mode], {
        input: JSON.stringify({ ...input, ...fields, prompt: state.prompt, proposal: state.proposal }),
        encoding: "utf8",
        cwd: input.cwd,
        timeout: 20_000,
        maxBuffer: 2 * 1024 * 1024,
    });

    if (result.error) {
        throw result.error;
    }

    if (result.status !== 0 && result.status !== 2) {
        throw new Error(`write-gate.sh failed: ${result.stderr.trim()}`);
    }

    const records = result.stdout
        .split("\n")
        .filter(Boolean)
        .map((line) => JSON.parse(line) as GateRecord);
    return { status: result.status, reason: result.stderr.trim(), records };
}

type HumanEvent = { id: string; prompt: string; turnId: string | null };

function readHuman(path: string): HumanEvent | null {
    if (!existsSync(path)) {
        return null;
    }

    return JSON.parse(readFileSync(path, "utf8")) as HumanEvent;
}

function writeHuman(path: string, event: HumanEvent): void {
    const temporary = `${path}.${process.pid}.tmp`;

    try {
        writeFileSync(temporary, JSON.stringify(event), { mode: 0o600 });
        renameSync(temporary, path);
    } finally {
        rmSync(temporary, { force: true });
    }
}

function humanCurrent(state: State, journal: string): boolean {
    const latest = readHuman(journal);
    return latest !== null && latest.id === state.humanId && latest.prompt === "ok" && state.prompt === "ok";
}

function dispatch(input: HookInput, state: State, journal: string): number {
    const event = input.hook_event_name;

    if (event === "SessionStart") {
        if (input.source === "startup" || input.source === "clear") {
            Object.assign(state, freshState());
            delete state.stopFeedback;
        } else if (input.source === "resume") {
            state.prompt = "";
            state.turnId = null;

            if (state.proposal) {
                state.proposal.approved = false;
            }
        }

        reconcile(state);
        return 0;
    }

    reconcile(state);

    if (event === "UserPromptSubmit") {
        if (typeof input.prompt !== "string") {
            throw new Error("missing user prompt");
        }

        // The bridge supplies provenance. A Stop retry can also come back as a
        // prompt carrying the exact reason we sent; match that complete,
        // uniquely tagged reason, never a substring.
        const feedback = state.stopFeedback && input.prompt === state.stopFeedback;

        if (input.synthetic === true || input.continuation === true || feedback) {
            state.turnId = input.turn_id ?? state.turnId;

            if (feedback) {
                delete state.stopFeedback;
            }

            return 0;
        }

        const latest = readHuman(journal);

        if (!input.human_event_id || latest?.id !== input.human_event_id) {
            // A newer human message arrived while this event waited for the lock.
            return 0;
        }

        const wasApproved = state.proposal?.approved === true;
        state.humanId = input.human_event_id;
        state.prompt = input.prompt;
        state.turnId = input.turn_id ?? null;
        delete state.stopFeedback;

        if (state.proposal) {
            // An ok received before presentation never approves a future plan.
            state.proposal.approved = input.prompt === "ok" && state.proposal.shown;
        }

        if (input.prompt !== "ok" && (state.inFlight.length || wasApproved)) {
            context(
                event,
                "Implementation paused. Request cancellation of running mutating commands using the client's interrupt controls. Keep the batch paused until a new exact ok; reading remains allowed.",
            );
        }

        return 0;
    }

    if (event === "Interrupt") {
        if (input.turn_id && state.turnId && input.turn_id !== state.turnId) {
            return 0;
        }

        if (input.human_event_id && readHuman(journal)?.id !== input.human_event_id) {
            return 0;
        }

        state.humanId = input.human_event_id ?? state.humanId;
        state.prompt = "";
        state.turnId = null;
        state.inFlight = [];
        delete state.stopFeedback;

        if (state.proposal) {
            state.proposal.approved = false;
        }

        return 0;
    }

    if (event === "PreToolUse") {
        const effect = gateEffect(input);
        const unrestricted = !effect.shell && effect.paths.every(exemptPath);

        if (!unrestricted && !humanCurrent(state, journal)) {
            console.error("write-gate: this change is not authorized by the latest human message.");
            return 2;
        }

        if (!unrestricted && (input.turn_id ?? null) !== state.turnId) {
            console.error("write-gate: this change is not authorized in the current human turn.");
            return 2;
        }

        const records: GateRecord[] = [];

        for (const path of effect.paths) {
            if (ungated(path)) {
                continue;
            }

            const result = gate("pre-write", input, state, { tool_input: { file_path: path } });

            if (result.status) {
                console.error(result.reason);
                return result.status;
            }

            records.push(...result.records);
        }

        if (!unrestricted && !humanCurrent(state, journal)) {
            console.error("write-gate: approval was superseded by a newer human message; mutation paused.");
            return 2;
        }

        state.plansWritten = unique([...state.plansWritten, ...records.flatMap((record) => record.plan_written ?? [])]);

        if (!effect.readonly && !unrestricted) {
            state.inFlight = unique([...state.inFlight, input.tool_use_id ?? input.tool_name ?? "write"]);
        }

        return 0;
    }

    if (event === "PostToolUse" || event === "PostToolUseFailure") {
        const effect = gateEffect(input);
        const callId = input.tool_use_id ?? input.tool_name ?? "write";
        state.inFlight = state.inFlight.filter((value) => value !== callId);

        if (
            event === "PostToolUse" &&
            succeeded(input.tool_response) &&
            state.proposal &&
            effect.removed.includes(state.proposal.path)
        ) {
            state.proposal = null;
        }

        reconcile(state);
        return 0;
    }

    if (event === "Stop") {
        if (state.turnId !== null && (input.turn_id ?? null) !== state.turnId) {
            return 0;
        }

        const result = gate("stop", input, state, { plans_written: state.plansWritten });

        if (result.records.some((record) => record.ambiguous)) {
            state.proposal = null;
        }

        for (const { presented, hash } of result.records) {
            if (!presented || !hash) {
                continue;
            }

            const current = snapshot(presented);

            if (!current || current.hash !== hash) {
                continue;
            }

            if (!state.proposal || !sameVersion(state.proposal, current)) {
                state.proposal = proposalFor(current);
            }

            state.proposal.shown = true;
        }

        if (result.status === 2) {
            state.stopFeedback = `[agent-hooks correction ${randomUUID()}]\n${result.reason}`;
            console.error(state.stopFeedback);
            return 2;
        }

        state.plansWritten = [];
        delete state.stopFeedback;
        return 0;
    }

    throw new Error(`unsupported hook event: ${event}`);
}

function main(namespace: string, normalize: (source: string) => string, locked: boolean): number {
    if (typeof namespace !== "string" || !/^[a-z][a-z0-9-]*$/.test(namespace)) {
        throw new Error("usage: gate.ts <client>");
    }

    let source = normalize(readFileSync(0, "utf8"));
    const input = JSON.parse(source) as HookInput;
    currentEvent = input.hook_event_name;

    if (typeof input.session_id !== "string" || !input.session_id) {
        throw new Error("missing session_id");
    }

    if (typeof input.cwd !== "string" || !statSync(input.cwd).isDirectory()) {
        throw new Error("missing or invalid cwd");
    }

    if (["PreToolUse", "PostToolUse", "PostToolUseFailure"].includes(input.hook_event_name)) {
        const effect = gateEffect(input);
        freePlanWrite = input.hook_event_name === "PreToolUse" && !effect.shell && effect.paths.every(exemptPath);

        // Reads and ungated writes never touch the proposal, so they skip the lock.
        if (effect.readonly || (!effect.shell && effect.paths.every(ungated))) {
            return 0;
        }
    }

    const root = join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local/state"), "agent-hooks", namespace);
    mkdirSync(root, { recursive: true, mode: 0o700 });
    const key = createHash("sha256").update(input.session_id).digest("hex");
    const path = join(root, `${key}.json`);
    const lock = join(root, `${key}.lock`);
    const journal = `${path}.human`;

    if (!locked) {
        // Publish human events before waiting for the policy lock. A question
        // must be able to revoke an approval check that is already running.
        const promptEvent = input.hook_event_name === "UserPromptSubmit";
        const markedSynthetic = input.synthetic === true || input.continuation === true;
        const feedback =
            promptEvent && existsSync(path) ? JSON.parse(readFileSync(path, "utf8")).stopFeedback : undefined;
        const correlated = typeof feedback === "string" && input.prompt === feedback;
        const latest = readHuman(journal);
        const interrupt =
            input.hook_event_name === "Interrupt" &&
            !(input.turn_id && latest?.turnId && input.turn_id !== latest.turnId);

        if ((promptEvent && !markedSynthetic && !correlated) || interrupt) {
            if (promptEvent && typeof input.prompt !== "string") {
                throw new Error("missing user prompt");
            }

            input.human_event_id = randomUUID();
            writeHuman(journal, {
                id: input.human_event_id,
                prompt: interrupt ? "" : (input.prompt ?? ""),
                turnId: input.turn_id ?? null,
            });
            source = JSON.stringify(input);
        }

        closeSync(openSync(lock, "a", 0o600));
        chmodSync(lock, 0o600);
        const result = spawnSync(
            "flock",
            ["-x", "-w", "20", lock, process.execPath, "--experimental-strip-types", entrypoint, namespace, "--locked"],
            {
                input: source,
                encoding: "utf8",
                maxBuffer: 2 * 1024 * 1024,
            },
        );

        if (result.error) {
            throw result.error;
        }

        process.stdout.write(result.stdout);
        process.stderr.write(result.stderr);

        if (result.status !== 0 && result.status !== 2) {
            throw new Error("could not run the locked hook");
        }

        return result.status;
    }

    const stored = existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : freshState();
    const state: State = stored.protocol === 3 ? stored : freshState();

    if (typeof state.prompt !== "string" || !Array.isArray(state.plansWritten) || !Array.isArray(state.inFlight)) {
        throw new Error("invalid hook state");
    }

    if (
        state.proposal &&
        (typeof state.proposal.id !== "string" ||
            typeof state.proposal.path !== "string" ||
            typeof state.proposal.hash !== "string" ||
            typeof state.proposal.identity !== "string" ||
            typeof state.proposal.shown !== "boolean" ||
            typeof state.proposal.approved !== "boolean")
    ) {
        throw new Error("invalid proposal state");
    }

    const code = dispatch(input, state, journal);
    const temporary = `${path}.${process.pid}.tmp`;

    try {
        writeFileSync(temporary, JSON.stringify(state), { mode: 0o600 });
        renameSync(temporary, path);
    } finally {
        rmSync(temporary, { force: true });
    }

    return code;
}

// The exit code for the hook event on stdin, after the client's bridge has
// normalized it: 0 allows, 2 blocks. A broken check blocks, except an exempt
// write and the end of a turn.
export function run(namespace: string, normalize = (source: string) => source, locked = false): number {
    try {
        return main(namespace, normalize, locked);
    } catch (error) {
        const detail = error instanceof Error ? error.message : String(error);

        if (freePlanWrite) {
            console.error(`agent-hooks: proposal bookkeeping unavailable: ${detail}; allowing the exempt write.`);
            return 0;
        }

        if (currentEvent === "Stop") {
            console.error(`agent-hooks: stop check unavailable: ${detail}; allowing turn to end.`);
            return 0;
        }

        console.error(`agent-hooks: ${detail}; operation blocked.`);
        return 2;
    }
}

if (import.meta.main) {
    process.exitCode = run(process.argv[2], undefined, process.argv[3] === "--locked");
}
