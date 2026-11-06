/**
 * The hook event both engines read, and what a tool call does to files. The
 * event is the hook JSON most clients send as it is; a client bridge adds the
 * provenance fields and translates whatever else its client does otherwise.
 */
import { realpathSync } from "node:fs";
import { basename, dirname, isAbsolute, resolve } from "node:path";
import { expandHome, shellEffect } from "./shell-policy.ts";

export type HookInput = {
    session_id: string;
    cwd: string;
    hook_event_name: string;
    turn_id?: string;
    tool_use_id?: string;
    // Set only inside a sub-agent, which shares the lead's session.
    agent_id?: string;
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
// `paths` are the files a file tool or patch writes; a shell command names none.
// `reads` are the files a shell command reads through cat, head, tail or sed -n.
export type Effect = { paths: string[]; removed: string[]; reads: string[]; shell: boolean; readonly: boolean };
const writeTools = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit"]);
export const unique = (items: string[]) => [...new Set(items)].sort();

export function canonicalPath(path: string): string {
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

export function fullPath(value: unknown, cwd: string): string {
    if (typeof value !== "string" || !value || /[\n\0]/.test(value)) {
        throw new Error("missing or invalid file path");
    }

    const path = expandHome(value);
    return canonicalPath(isAbsolute(path) ? path : `${cwd}/${path}`);
}

export function toolEffect(input: HookInput): Effect {
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

        return { paths, removed, reads: [], shell: false, readonly: false };
    }

    if (writeTools.has(tool)) {
        return {
            paths: [fullPath(args.file_path ?? args.notebook_path, input.cwd)],
            removed: [],
            reads: [],
            shell: false,
            readonly: false,
        };
    }

    if (tool === "Bash") {
        if (typeof args.command !== "string") {
            throw new Error("missing shell command");
        }

        const effect = shellEffect(args.command, fullPath(args.workdir ?? input.cwd, input.cwd));
        return { paths: [], removed: [], reads: effect.reads, shell: true, readonly: effect.readonly };
    }

    return { paths: [], removed: [], reads: [], shell: false, readonly: true };
}

export function succeeded(response: unknown): boolean {
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

export function context(event: string, text: string): void {
    if (text) {
        process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: event, additionalContext: text } }));
    }
}
