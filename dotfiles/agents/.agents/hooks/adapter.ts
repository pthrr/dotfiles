/** Serialize client events into one versioned proposal and exact human consent. */
import { spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import {
    chmodSync,
    closeSync,
    existsSync,
    mkdirSync,
    openSync,
    readFileSync,
    realpathSync,
    renameSync,
    rmSync,
    statSync,
    writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { expandHome, shellEffect } from "./shell-policy.ts";

type Client = "claude" | "codex" | "opencode";
type HookInput = {
    session_id: string;
    cwd: string;
    hook_event_name: string;
    turn_id?: string;
    tool_use_id?: string;
    source?: string;
    prompt?: string;
    tool_name?: string;
    tool_input?: Record<string, unknown>;
    tool_response?: unknown;
    last_assistant_message?: string | null;
    stop_hook_active?: boolean;
    // Provenance supplied by the client bridge, never inferred from an "ok".
    synthetic?: boolean;
    continuation?: boolean;
    human_event_id?: string;
};
type Snapshot = { path: string; hash: string; identity: string };
type Proposal = Snapshot & { id: string; shown: boolean; approved: boolean };
type State = {
    protocol: 3;
    humanId: string | null;
    prompt: string;
    turnId: string | null;
    rules: string[];
    proposal: Proposal | null;
    plansWritten: string[];
    inFlight: string[];
    stopFeedback?: string;
};
type Effect = { paths: string[]; removed: string[]; shell: boolean; readonly: boolean };
type GateRecord = { ambiguous?: boolean; plan_written?: string; governed_by?: string; presented?: string; hash?: string };
const injected = /^<(task-notification|command-name|local-command-caveat|local-command-stdout)>/;
const entrypoint = fileURLToPath(import.meta.url);
const hooks = dirname(entrypoint);
const writeTools = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit"]);
const freshState = (): State => ({
    protocol: 3,
    humanId: null,
    prompt: "",
    turnId: null,
    rules: [],
    proposal: null,
    plansWritten: [],
    inFlight: [],
});
const unique = (items: string[]) => [...new Set(items)].sort();
let currentEvent: string | undefined;
let freePlanWrite = false;

function canonicalPath(path: string): string {
    try {
        return realpathSync(path);
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
            throw error;
        }

        const parent = dirname(path);

        if (parent === path) {
            throw error;
        }

        return resolve(canonicalPath(parent), basename(path));
    }
}

function fullPath(value: unknown, cwd: string): string {
    if (typeof value !== "string" || !value || /[\n\0]/.test(value)) {
        throw new Error("missing or invalid file path");
    }

    const path = expandHome(value);
    return canonicalPath(isAbsolute(path) ? path : `${cwd}/${path}`);
}

// Only declared file targets qualify. A shell working directory is never a target.
// Keep this fast path in step with write-gate.sh; exempt writes need no storage.
function exemptPath(path: string): boolean {
    const userHome = canonicalPath(homedir());
    const roots = [
        ".claude", ".codex", ".agents", ".config/opencode", ".local/share/opencode", "tmp",
    ].map((directory) => join(userHome, directory));
    roots.push("/tmp");
    return basename(path) === "PLAN.md" || roots.some((directory) => path.startsWith(`${directory}/`));
}

function toolEffect(input: HookInput): Effect {
    const tool = input.tool_name ?? "";
    const args = input.tool_input ?? {};

    if (typeof args !== "object" || Array.isArray(args)) {
        throw new Error("tool_input must be an object");
    }

    if (tool === "apply_patch") {
        const patch = args.command;

        if (
            typeof patch !== "string" ||
            !patch.trimStart().startsWith("*** Begin Patch\n") ||
            !patch.trimEnd().endsWith("*** End Patch")
        ) {
            throw new Error("cannot identify the files in this patch");
        }

        const targets = [...patch.matchAll(/^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$/gm)];
        const paths = unique(targets.map((match) => fullPath(match[1], input.cwd)));
        const deletions = [...patch.matchAll(/^\*\*\* Delete File: (.+)$/gm)];
        const moves = [...patch.matchAll(/^\*\*\* Update File: (.+)\n\*\*\* Move to: /gm)];
        const removed = unique([...deletions, ...moves].map((match) => fullPath(match[1], input.cwd)));

        if (!paths.length) {
            throw new Error("patch has no recognized file targets");
        }

        return { paths, removed, shell: false, readonly: false };
    }

    if (writeTools.has(tool)) {
        return {
            paths: [fullPath(args.file_path ?? args.notebook_path, input.cwd)],
            removed: [],
            shell: false,
            readonly: false,
        };
    }

    if (tool === "Bash") {
        if (typeof args.command !== "string") {
            throw new Error("missing shell command");
        }

        const workdir = fullPath(args.workdir ?? input.cwd, input.cwd);
        const effect = shellEffect(args.command, workdir);
        return {
            paths: effect.readonly ? [] : [fullPath(".shell-command", workdir)],
            removed: [],
            shell: true,
            readonly: effect.readonly,
        };
    }

    return { paths: [], removed: [], shell: false, readonly: true };
}

function succeeded(response: unknown): boolean {
    if (typeof response === "string") {
        try {
            response = JSON.parse(response);
        } catch {
            return true;
        }
    }

    if (!response || typeof response !== "object") {
        return true;
    }

    const value = response as Record<string, unknown>;
    return !value.isError && !value.is_error && (value.exit_code == null || value.exit_code === 0);
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

function ruleContext(paths: string[], input: HookInput, state: State): string {
    if (!succeeded(input.tool_response) || !paths.length) {
        return "";
    }

    const bodies: string[] = [];

    for (const path of paths) {
        const result = spawnSync("bash", [join(hooks, "rules.sh"), path], {
            encoding: "utf8",
            timeout: 5_000,
            maxBuffer: 256 * 1024,
        });

        if (result.status !== 0 || !result.stdout) {
            continue;
        }

        for (const file of result.stdout.split("\n").filter(Boolean)) {
            if (state.rules.includes(file)) {
                continue;
            }

            state.rules.push(file);

            try {
                bodies.push(readFileSync(file, "utf8").replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, "").trim());
            } catch {
                // An unreadable rule cannot turn a completed write into a failure.
            }
        }
    }

    return bodies.filter(Boolean).join("\n\n");
}

function gate(mode: "pre-write" | "stop", input: HookInput, state: State, fields: Record<string, unknown> = {}) {
    const result = spawnSync("bash", [join(hooks, "write-gate.sh"), mode], {
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

    const records = result.stdout.split("\n").filter(Boolean).map((line) => JSON.parse(line) as GateRecord);
    return { status: result.status, reason: result.stderr.trim(), records };
}

function context(event: string, text: string): void {
    if (text) {
        process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: event, additionalContext: text } }));
    }
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

function dispatch(client: Client, input: HookInput, state: State, journal: string): number {
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

        // OpenCode supplies provenance. Claude's injected notifications have
        // stable tags. Codex exposes its Stop retry as the exact reason we sent;
        // match that complete, uniquely tagged reason, never a substring.
        const feedback = client === "codex" && state.stopFeedback && input.prompt === state.stopFeedback;

        if (input.synthetic === true || input.continuation === true || injected.test(input.prompt) || feedback) {
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
            context(event, "Implementation paused. Request cancellation of running mutating commands using the client's interrupt controls. Keep the batch paused until a new exact ok; reading remains allowed.");
        }

        return 0;
    }

    if (event === "Interrupt") {
        if (client !== "claude" && input.turn_id && state.turnId && input.turn_id !== state.turnId) {
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
        const effect = toolEffect(input);
        const unrestricted = !effect.shell && effect.paths.every(exemptPath);

        if (!unrestricted && !humanCurrent(state, journal)) {
            console.error("write-gate: this change is not authorized by the latest human message.");
            return 2;
        }

        if (!unrestricted && client !== "claude" && (input.turn_id ?? null) !== state.turnId) {
            console.error("write-gate: this change is not authorized in the current human turn.");
            return 2;
        }

        const records: GateRecord[] = [];

        for (const path of effect.paths) {
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
        const effect = toolEffect(input);
        const callId = input.tool_use_id ?? input.tool_name ?? "write";
        state.inFlight = state.inFlight.filter((value) => value !== callId);

        if (event === "PostToolUse" && succeeded(input.tool_response) && state.proposal && effect.removed.includes(state.proposal.path)) {
            state.proposal = null;
        }

        reconcile(state);

        if (event === "PostToolUse") {
            context(event, ruleContext(effect.shell ? [] : effect.paths, input, state));
        }

        return 0;
    }

    if (event === "Stop") {
        if (client !== "claude" && state.turnId !== null && (input.turn_id ?? null) !== state.turnId) {
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

function main(): number {
    const client = process.argv[2];

    if (client !== "claude" && client !== "codex" && client !== "opencode") {
        throw new Error("usage: adapter.ts claude|codex|opencode");
    }

    let source = readFileSync(0, "utf8");
    const input = JSON.parse(source) as HookInput;
    currentEvent = input.hook_event_name;

    if (typeof input.session_id !== "string" || !input.session_id) {
        throw new Error("missing session_id");
    }

    if (typeof input.cwd !== "string" || !statSync(input.cwd).isDirectory()) {
        throw new Error("missing or invalid cwd");
    }

    if (input.hook_event_name === "PreToolUse") {
        const effect = toolEffect(input);
        freePlanWrite = !effect.shell && effect.paths.every(exemptPath);

        if (effect.readonly || (!effect.shell && effect.paths.every((path) => basename(path) !== "PLAN.md" && exemptPath(path)))) {
            return 0;
        }
    }

    const root = join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local/state"), "agent-hooks", client);
    mkdirSync(root, { recursive: true, mode: 0o700 });
    const key = createHash("sha256").update(input.session_id).digest("hex");
    const path = join(root, `${key}.json`);
    const lock = join(root, `${key}.lock`);
    const journal = `${path}.human`;

    if (process.argv[3] !== "--locked") {
        // Publish human events before waiting for the policy lock. A question
        // must be able to revoke an approval check that is already running.
        const promptEvent = input.hook_event_name === "UserPromptSubmit";
        const markedSynthetic = input.synthetic === true || input.continuation === true || injected.test(input.prompt ?? "");
        const feedback = client === "codex" && promptEvent && existsSync(path)
            ? JSON.parse(readFileSync(path, "utf8")).stopFeedback
            : undefined;
        const correlated = typeof feedback === "string" && input.prompt === feedback;
        const latest = readHuman(journal);
        const interrupt = input.hook_event_name === "Interrupt" &&
            !(client !== "claude" && input.turn_id && latest?.turnId && input.turn_id !== latest.turnId);

        if ((promptEvent && !markedSynthetic && !correlated) || interrupt) {
            if (promptEvent && typeof input.prompt !== "string") {
                throw new Error("missing user prompt");
            }

            input.human_event_id = randomUUID();
            writeHuman(journal, {
                id: input.human_event_id,
                prompt: interrupt ? "" : input.prompt!,
                turnId: input.turn_id ?? null,
            });
            source = JSON.stringify(input);
        }

        closeSync(openSync(lock, "a", 0o600));
        chmodSync(lock, 0o600);
        const result = spawnSync("flock", ["-x", "-w", "20", lock, process.execPath, "--experimental-strip-types", entrypoint, client, "--locked"], {
            input: source,
            encoding: "utf8",
            maxBuffer: 2 * 1024 * 1024,
        });

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
    const state: State = stored.protocol === 3 ? stored : { ...freshState(), rules: stored.rules ?? [] };

    if (typeof state.prompt !== "string" || !Array.isArray(state.rules) || !Array.isArray(state.plansWritten) || !Array.isArray(state.inFlight)) {
        throw new Error("invalid hook state");
    }

    if (state.proposal && (typeof state.proposal.id !== "string" || typeof state.proposal.path !== "string" || typeof state.proposal.hash !== "string" || typeof state.proposal.identity !== "string" || typeof state.proposal.shown !== "boolean" || typeof state.proposal.approved !== "boolean")) {
        throw new Error("invalid proposal state");
    }

    const code = dispatch(client, input, state, journal);
    const temporary = `${path}.${process.pid}.tmp`;

    try {
        writeFileSync(temporary, JSON.stringify(state), { mode: 0o600 });
        renameSync(temporary, path);
    } finally {
        rmSync(temporary, { force: true });
    }

    return code;
}

try {
    process.exitCode = main();
} catch (error) {
    const detail = error instanceof Error ? error.message : String(error);

    if (freePlanWrite) {
        console.error(`agent-hooks: proposal bookkeeping unavailable: ${detail}; allowing the exempt write.`);
        process.exitCode = 0;
    } else if (currentEvent === "Stop") {
        console.error(`agent-hooks: stop check unavailable: ${detail}; allowing turn to end.`);
        process.exitCode = 0;
    } else {
        console.error(`agent-hooks: ${detail}; operation blocked.`);
        process.exitCode = 2;
    }
}
