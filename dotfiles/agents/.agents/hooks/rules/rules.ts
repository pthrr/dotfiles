/**
 * Show each agent the rules files that apply to what it does: the paths a tool
 * wrote or read, and the programs a shell command runs. Reading flake.nix or
 * running `nix build` is work in that field as much as writing a .nix file.
 *
 * Each agent sees each rule once per session: a sub-agent starts from a fresh
 * context, whatever the lead was shown. Every session start except a resume
 * shows them again, compaction included, since a summary keeps at most a gist.
 *
 * Independent of the approval gate: its own state, no lock, and it never
 * blocks. A rule that cannot be shown is no reason to fail a tool call, and two
 * agents writing the state at once can lose a record, which shows a rule twice.
 */
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { context, fullPath, succeeded, toolEffect } from "../event.ts";
import type { HookInput } from "../event.ts";

type State = { shown: Record<string, string[]> };
const match = join(dirname(fileURLToPath(import.meta.url)), "match.sh");

function ruleContext(paths: string[], command: string, shown: string[]): string {
    const queries = [...paths.map((path) => [path]), ...(command ? [["--command", command]] : [])];

    if (!queries.length) {
        return "";
    }

    const bodies: string[] = [];

    for (const query of queries) {
        const result = spawnSync("bash", [match, ...query], {
            encoding: "utf8",
            timeout: 5_000,
            maxBuffer: 256 * 1024,
        });

        if (result.status !== 0 || !result.stdout) {
            continue;
        }

        for (const file of result.stdout.split("\n").filter(Boolean)) {
            if (shown.includes(file)) {
                continue;
            }

            shown.push(file);

            try {
                bodies.push(
                    readFileSync(file, "utf8")
                        .replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, "")
                        .trim(),
                );
            } catch {
                // An unreadable rule cannot turn a completed write into a failure.
            }
        }
    }

    return bodies.filter(Boolean).join("\n\n");
}

function main(): void {
    const namespace = process.argv[2];

    if (typeof namespace !== "string" || !/^[a-z][a-z0-9-]*$/.test(namespace)) {
        throw new Error("usage: rules.ts <client>");
    }

    const input = JSON.parse(readFileSync(0, "utf8")) as HookInput;
    const event = input.hook_event_name;

    if (typeof input.session_id !== "string" || !input.session_id) {
        throw new Error("missing session_id");
    }

    const root = join(process.env.XDG_STATE_HOME ?? join(homedir(), ".local/state"), "agent-rules", namespace);
    mkdirSync(root, { recursive: true, mode: 0o700 });
    const path = join(root, `${createHash("sha256").update(input.session_id).digest("hex")}.json`);
    const state: State = existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : { shown: {} };

    if (event === "SessionStart") {
        if (input.source !== "resume") {
            state.shown = {};
        }
    } else if (event === "PostToolUse" || event === "PostToolUseFailure") {
        const effect = toolEffect(input);
        // A write or read counts once it happened; a command counts once it ran,
        // whatever its exit code: a failing `nix build` is when its rules matter.
        const happened = event === "PostToolUse" && succeeded(input.tool_response);
        const args = input.tool_input ?? {};
        const read =
            happened && input.tool_name === "Read" && typeof args.file_path === "string"
                ? [fullPath(args.file_path, input.cwd)]
                : [];
        // cat, head, tail and sed -n read too; without a read tool they are the
        // only reads.
        const shellRead = happened ? effect.reads : [];
        const written = happened ? effect.paths : [];
        const command = effect.shell && typeof args.command === "string" ? args.command : "";
        const agent = input.agent_id ?? "lead";
        const shown = state.shown[agent] ?? [];
        state.shown[agent] = shown;
        context(event, ruleContext([...written, ...read, ...shellRead], command, shown));
    } else {
        return;
    }

    const temporary = `${path}.${process.pid}.tmp`;

    try {
        writeFileSync(temporary, JSON.stringify(state), { mode: 0o600 });
        renameSync(temporary, path);
    } finally {
        rmSync(temporary, { force: true });
    }
}

try {
    main();
} catch (error) {
    console.error(`agent-rules: ${error instanceof Error ? error.message : String(error)}; no rules shown.`);
}

process.exitCode = 0;
