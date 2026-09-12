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
type State = { prompt: string; turnId: string | null; active: boolean; touched: string[]; stopFeedback?: string };
const entrypoint = fileURLToPath(import.meta.url);
const hooks = dirname(entrypoint);
const writeTools = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit", "apply_patch"]);
const freshState = (): State => ({ prompt: "", turnId: null, active: false, touched: [] });

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

function toolEffect(input: HookInput): { paths: string[]; reads: string[] } {
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
        return { paths: [...new Set(paths)].sort(), reads: [] };
    }
    if (writeTools.has(tool)) return { paths: [fullPath(args.file_path ?? args.notebook_path, input.cwd)], reads: [] };
    if (tool === "Bash") {
        if (typeof args.command !== "string") throw new Error("missing shell command");
        const workdir = fullPath(args.workdir ?? input.cwd, input.cwd);
        const effect = shellEffect(args.command, workdir);
        // Arbitrary programs have unknowable write sets. Require a plan in each
        // identifiable working directory; patches get per-file checks instead.
        return {
            paths: effect.readonly ? [] : effect.directories.map((dir) => fullPath(".shell-command", dir)),
            reads: effect.reads,
        };
    }
    if (["Read", "read_file"].includes(tool) || tool.endsWith("__read_file")) {
        const path = args.file_path ?? args.path;
        return { paths: [], reads: path ? [fullPath(path, input.cwd)] : [] };
    }
    return { paths: [], reads: [] };
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

function skillRead(client: Client, input: HookInput, reads: string[]): boolean {
    if (!succeeded(input.tool_response)) return false;
    if (input.tool_name === "Skill" && input.tool_input?.skill === "software-design") return true;
    // Clients with no Skill tool load a skill by reading its file, so there the
    // read IS the load. Claude has one, so a Read or `cat` of SKILL.md is
    // ordinary file access — editing the skill, grepping it — and arming on
    // that taxed every later write in any repo where the file had been opened.
    return (
        client !== "claude" &&
        reads.some((path) => basename(path) === "SKILL.md" && basename(dirname(path)) === "software-design")
    );
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
            state.active ||= skillRead(client, input, effect.reads);
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
    if (typeof input.session_id !== "string" || !input.session_id) throw new Error("missing session_id");
    if (typeof input.cwd !== "string" || !statSync(input.cwd).isDirectory()) throw new Error("missing or invalid cwd");
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
    if (typeof state.prompt !== "string" || typeof state.active !== "boolean" || !Array.isArray(state.touched))
        throw new Error("invalid hook state");
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
    // A generic nonzero exit can let a pre-tool call proceed; exit 2 blocks it.
    console.error(`agent-hooks: ${error instanceof Error ? error.message : error}; operation blocked.`);
    process.exitCode = 2;
}
