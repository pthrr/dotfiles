/** Translate harness lifecycle events into the shared shell checks.
 * Hooks own state per client and session. Event inputs avoid private transcript
 * formats; Codex turn IDs prevent consent leaking into a different turn.
 */
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
    chmodSync,
    closeSync,
    existsSync,
    mkdirSync,
    mkdtempSync,
    openSync,
    readFileSync,
    realpathSync,
    renameSync,
    rmSync,
    statSync,
    writeFileSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { basename, dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { expandHome, shellEffect } from "./shell-policy.ts";

type Client = "claude" | "codex" | "opencode";
type HookInput = {
    session_id: string;
    cwd: string;
    hook_event_name: string;
    turn_id?: string;
    source?: string;
    prompt?: string;
    tool_name?: string;
    tool_input?: Record<string, unknown>;
    tool_response?: unknown;
    last_assistant_message?: string | null;
    stop_hook_active?: boolean;
};
type State = {
    prompt: string;
    turnId: string | null;
    active: boolean;
    touched: string[];
    rules: string[];
    stopFeedback?: string;
};
const entrypoint = fileURLToPath(import.meta.url);
const hooks = dirname(entrypoint);
const writeTools = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit", "apply_patch"]);
const freshState = (): State => ({ prompt: "", turnId: null, active: false, touched: [], rules: [] });
let currentEvent: string | undefined;

function canonicalPath(path: string): string {
    try {
        return realpathSync(path);
    } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
        const parent = dirname(path);
        if (parent === path) throw error;
        return resolve(canonicalPath(parent), basename(path));
    }
}

function fullPath(value: unknown, cwd: string): string {
    if (typeof value !== "string" || !value || /[\n\0]/.test(value)) throw new Error("missing or invalid file path");
    const path = expandHome(value);
    // Resolve existing symlinks before normalizing '..' and new path components.
    return canonicalPath(isAbsolute(path) ? path : `${cwd}/${path}`);
}

// Only write sets matter here. Reads used to be collected too, so that reading
// skills/software-design/SKILL.md could arm the loop; activation is manual now,
// and nothing else ever consumed them.
function toolEffect(input: HookInput): { paths: string[] } {
    const tool = input.tool_name ?? "",
        args = input.tool_input ?? {};
    if (typeof args !== "object" || Array.isArray(args)) throw new Error("tool_input must be an object");
    if (tool === "apply_patch") {
        const patch = args.command;
        if (
            typeof patch !== "string" ||
            !patch.trimStart().startsWith("*** Begin Patch\n") ||
            !patch.trimEnd().endsWith("*** End Patch")
        )
            throw new Error("cannot identify the files in this patch");
        const paths = [...patch.matchAll(/^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$/gm)].map(
            (match) => fullPath(match[1], input.cwd),
        );
        if (!paths.length) throw new Error("patch has no recognized file targets");
        return { paths: [...new Set(paths)].sort() };
    }
    if (writeTools.has(tool)) return { paths: [fullPath(args.file_path ?? args.notebook_path, input.cwd)] };
    if (tool === "Bash") {
        if (typeof args.command !== "string") throw new Error("missing shell command");
        const workdir = fullPath(args.workdir ?? input.cwd, input.cwd);
        const effect = shellEffect(args.command, workdir);
        // Arbitrary programs have unknowable write sets. Require a plan in each
        // identifiable working directory; patches get per-file checks instead.
        return { paths: effect.readonly ? [] : effect.directories.map((dir) => fullPath(".shell-command", dir)) };
    }
    return { paths: [] };
}

function succeeded(response: unknown): boolean {
    if (typeof response === "string") {
        try {
            response = JSON.parse(response);
        } catch {
            return true;
        }
    }
    if (!response || typeof response !== "object") return true;
    const value = response as Record<string, unknown>;
    return !value.isError && !value.is_error && (value.exit_code == null || value.exit_code === 0);
}

// The loop is armed by hand and never by inference. A successful Skill tool_use
// is the one signal here; the other is `$software-design` typed into a Codex
// prompt, handled in dispatch. Reading skills/software-design/SKILL.md used to
// arm it on clients with no Skill tool, on the theory that there the read IS the
// load — but a read is also how the file gets edited, grepped or quoted, so that
// path armed the loop for people who had merely opened it. Opening a file is not
// a decision to work under a design loop.
// Naming it is a fact about the user's message; "this task looks like a fit" is a
// claim about the model's judgement. The skill's own description says INVOKE ONLY
// WHEN THE USER ASKS FOR IT BY NAME, but a description is a prompt — nothing stopped
// a model from reading an ordinary refactor as a good fit and arming a loop the user
// never chose and cannot leave without ending the session. The prompt is the record
// of what was actually asked for, so the gate reads that instead.
//
// The skill content still loads either way. What this withholds is the enforcement,
// which is the part the user did not ask for.
function skillLoaded(input: HookInput, prompt: string): boolean {
    if (!succeeded(input.tool_response)) return false;
    if (input.tool_name !== "Skill" || input.tool_input?.skill !== "software-design") return false;
    return /software-design|design[ -]loop/i.test(prompt);
}

// Rules fire on what a turn wrote, never on what it loaded. A file in ../rules with
// a matching `when:` glob applies in any session — implementation, a one-line fix,
// one that has never heard of the design loop — which is the difference between
// this and a skill.
//
// Injected once per file per session: thirty Rust edits must not repeat the same
// paragraph thirty times. The ledger is session state, so a new session sees them
// again, which is right — a new session has not read them.
//
// A failure here is silent. The tool call already succeeded, and an unreadable
// rules file is not a reason to report an error against work that landed.
function ruleContext(paths: string[], input: HookInput, state: State): string {
    if (!succeeded(input.tool_response) || !paths.length) return "";
    const bodies: string[] = [];
    for (const path of paths) {
        const result = spawnSync("bash", [join(hooks, "rules.sh"), path], {
            encoding: "utf8",
            timeout: 5_000,
            maxBuffer: 256 * 1024,
        });
        if (result.status !== 0 || !result.stdout) continue;
        for (const file of result.stdout.split("\n").filter(Boolean)) {
            if (state.rules.includes(file)) continue;
            state.rules.push(file);
            try {
                // Strip the frontmatter: `when:` is configuration for the hook, not
                // guidance for the reader.
                bodies.push(readFileSync(file, "utf8").replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, "").trim());
            } catch {
                /* unreadable rule: recorded as seen, so it is not retried every write */
            }
        }
    }
    return bodies.filter(Boolean).join("\n\n");
}

function runCheck(script: string, mode: string | null, input: HookInput, state: State, filePath?: string): number {
    // The established validators consume this small Claude-shaped protocol.
    // Clients supply the same facts, keeping one implementation of policy.
    const content: Record<string, unknown>[] = [];
    if (state.active) content.push({ type: "tool_use", name: "Skill", input: { skill: "software-design" } });
    for (const path of state.touched) content.push({ type: "tool_use", name: "Write", input: { file_path: path } });
    if (input.last_assistant_message != null) content.push({ type: "text", text: input.last_assistant_message });
    const rows = [
        { type: "user", message: { content: state.prompt } },
        { type: "assistant", message: { content } },
    ];
    const temporary = mkdtempSync(join(tmpdir(), "agent-hook-"));
    try {
        const transcript = join(temporary, "transcript.jsonl");
        writeFileSync(transcript, rows.map((row) => JSON.stringify(row)).join("\n") + "\n", { mode: 0o600 });
        const payload = {
            ...input,
            transcript_path: transcript,
            ...(filePath ? { tool_input: { file_path: filePath } } : {}),
        };
        const result = spawnSync("bash", [join(hooks, script), ...(mode ? [mode] : [])], {
            input: JSON.stringify(payload),
            encoding: "utf8",
            cwd: input.cwd,
            timeout: 20_000,
            maxBuffer: 2 * 1024 * 1024,
        });
        if (result.error) throw result.error;
        if (result.status !== 0 && result.status !== 2) throw new Error(`${script} failed: ${result.stderr.trim()}`);
        process.stdout.write(result.stdout);
        process.stderr.write(result.stderr);
        if (mode === "stop" && result.status === 2) state.stopFeedback = result.stderr.trim();
        return result.status;
    } finally {
        rmSync(temporary, { recursive: true, force: true });
    }
}

function dispatch(client: Client, input: HookInput, state: State): number {
    const event = input.hook_event_name;
    if (event === "SessionStart") {
        if (input.source === "startup" || input.source === "clear") {
            Object.assign(state, freshState());
            delete state.stopFeedback;
        } else if (input.source === "resume") {
            Object.assign(state, { prompt: "", turnId: null, touched: [] });
        }
        return runCheck("design-loop.sh", "activate", input, state);
    }
    if (event === "UserPromptSubmit") {
        if (typeof input.prompt !== "string") throw new Error("missing user prompt");
        // A rejected Codex Stop creates a synthetic user prompt. Quoted "OK" or
        // a path named "yes" in that feedback must never grant human consent.
        const continuation = !!state.stopFeedback && input.prompt.includes(state.stopFeedback);
        delete state.stopFeedback;
        Object.assign(state, { prompt: continuation ? "" : input.prompt, turnId: input.turn_id ?? null, touched: [] });
        if (client === "codex" && /\$software-design\b/.test(input.prompt)) state.active = true;
        return 0;
    }
    if (client !== "claude" && (input.turn_id ?? null) !== state.turnId) {
        Object.assign(state, { prompt: "", turnId: input.turn_id ?? null, touched: [] });
    }
    if (event === "PreToolUse" || event === "PostToolUse") {
        const effect = toolEffect(input);
        if (event === "PostToolUse") {
            state.active ||= skillLoaded(input, state.prompt);
            const context = ruleContext(effect.paths, input, state);
            if (context)
                process.stdout.write(
                    JSON.stringify({
                        hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: context },
                    }),
                );
            return 0;
        }
        if (!effect.paths.length) return 0;
        const consent = runCheck("ask-first.sh", null, input, state);
        if (consent) return consent;
        // Check every file before recording any writes. Adding PLAN.md and source
        // in one patch cannot bypass a missing plan; renames check both endpoints.
        for (const path of effect.paths) {
            const code = runCheck("design-loop.sh", "pre-write", input, state, path);
            if (code) return code;
        }
        state.touched = [...new Set([...state.touched, ...effect.paths])].sort();
        return 0;
    }
    if (event === "Stop") return runCheck("design-loop.sh", "stop", input, state);
    if (event === "Interrupt") {
        Object.assign(state, { prompt: "", turnId: null, touched: [] });
        return 0;
    }
    throw new Error(`unsupported hook event: ${event}`);
}

function main(): number {
    const client = process.argv[2];
    if (client !== "claude" && client !== "codex" && client !== "opencode")
        throw new Error("usage: adapter.ts claude|codex|opencode");
    const source = readFileSync(0, "utf8"),
        input = JSON.parse(source) as HookInput;
    currentEvent = input.hook_event_name;
    if (typeof input.session_id !== "string" || !input.session_id) throw new Error("missing session_id");
    if (typeof input.cwd !== "string" || !statSync(input.cwd).isDirectory()) throw new Error("missing or invalid cwd");
    // These events cannot change state or require a validator. In particular,
    // read-only tools must remain usable when the state filesystem cannot write.
    if (input.hook_event_name === "PreToolUse" && !toolEffect(input).paths.length) return 0;
    if (input.hook_event_name === "Stop" && input.stop_hook_active) return 0;
    const root = join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local/state"), "agent-hooks", client);
    mkdirSync(root, { recursive: true, mode: 0o700 });
    const key = createHash("sha256").update(input.session_id).digest("hex");
    const path = join(root, `${key}.json`),
        lock = join(root, `${key}.lock`);
    if (process.argv[3] !== "--locked") {
        closeSync(openSync(lock, "a", 0o600));
        chmodSync(lock, 0o600);
        // flock releases the lock even if a hook is interrupted or times out.
        const result = spawnSync(
            "flock",
            ["-x", "-w", "20", lock, process.execPath, "--experimental-strip-types", entrypoint, client, "--locked"],
            {
                input: source,
                encoding: "utf8",
                maxBuffer: 2 * 1024 * 1024,
            },
        );
        if (result.error) throw result.error;
        process.stdout.write(result.stdout);
        process.stderr.write(result.stderr);
        if (result.status !== 0 && result.status !== 2) throw new Error("could not run the locked hook");
        return result.status;
    }
    const state: State = existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : freshState();
    // A state file written before rules existed carries no `rules`. Coerce rather
    // than validate: throwing would break every session that was live at the moment
    // this shipped, on its next tool call, for a field it could not have known about.
    if (!Array.isArray(state.rules)) state.rules = [];
    if (typeof state.prompt !== "string" || typeof state.active !== "boolean" || !Array.isArray(state.touched))
        throw new Error("invalid hook state");
    // An inactive loop has nothing to check. Avoid the temporary transcript and
    // the redundant state write on every ordinary Claude response.
    if (input.hook_event_name === "Stop" && !state.active) return 0;
    const code = dispatch(client, input, state);
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
    if (currentEvent === "Stop") {
        // A broken stop check must not trap the assistant in an endless retry.
        // A deliberate validator rejection returns 2 from main and still blocks.
        console.error(`agent-hooks: stop check unavailable: ${detail}; allowing turn to end.`);
        process.exitCode = 0;
    } else {
        // A generic nonzero exit can let a pre-tool call proceed; exit 2 blocks it.
        console.error(`agent-hooks: ${detail}; operation blocked.`);
        process.exitCode = 2;
    }
}
