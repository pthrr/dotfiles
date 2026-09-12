/** OpenCode v1 plugin: translate its public hooks into the shared checks. */
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

type Part = { type: string; text?: string; synthetic?: boolean; ignored?: boolean };
type Message = {
    info: {
        id: string;
        role: string;
        parentID?: string;
        error?: unknown;
        time?: { completed?: number };
        agent?: string;
        providerID?: string;
        modelID?: string;
    };
    parts: Part[];
};
type Context = {
    directory: string;
    client: {
        session: {
            messages(input: { path: { id: string } }): Promise<{ data?: Message[]; error?: unknown }>;
            promptAsync(input: {
                path: { id: string };
                body: {
                    parts: Part[];
                    agent?: string;
                    model?: { providerID: string; modelID: string };
                };
            }): Promise<{ error?: unknown }>;
        };
    };
};
type Turn = {
    id: string | null;
    revision: number;
    checked: string | null;
    checking: boolean;
    correcting: boolean;
};
type ToolInput = { sessionID: string; tool: string; callID: string };
const adapter = fileURLToPath(new URL("../hooks/adapter.ts", import.meta.url));

function normalizeTool(tool: string, args: Record<string, unknown>) {
    if (tool === "apply_patch") return { tool_name: tool, tool_input: { command: args.patchText } };
    if (tool === "bash" || tool === "shell") return { tool_name: "Bash", tool_input: args };
    if (tool === "execute") return { tool_name: "Bash", tool_input: { command: "opencode-code-execution" } };
    const names: Record<string, string> = { write: "Write", edit: "Edit", multiedit: "MultiEdit", read: "Read" };
    if (names[tool]) return { tool_name: names[tool], tool_input: { file_path: args.filePath } };
    if (tool === "skill") return { tool_name: "Skill", tool_input: { skill: args.name } };
    return { tool_name: tool, tool_input: args };
}

export default async function sharedHooks({ directory, client }: Context) {
    const turns = new Map<string, Turn>();

    function check(sessionID: string, turn: Turn, event: string, fields: Record<string, unknown> = {}) {
        // Use Node, not process.execPath: in a compiled OpenCode plugin that is
        // the OpenCode executable. Spawn argv directly; never run model text.
        const result = spawnSync("node", ["--experimental-strip-types", adapter, "opencode"], {
            input: JSON.stringify({
                session_id: sessionID,
                cwd: directory,
                hook_event_name: event,
                turn_id: turn.id,
                ...fields,
            }),
            encoding: "utf8",
            timeout: 60_000,
            maxBuffer: 2 * 1024 * 1024,
        });
        if (result.error) throw result.error;
        if (result.status !== 0 && result.status !== 2)
            throw new Error(`agent-hooks: adapter failed (${result.status}): ${result.stderr.trim()}`);
        if (result.status === 2 && event !== "Stop") throw new Error(result.stderr.trim() || "agent-hooks: blocked");
        const output = result.stdout.trim() ? JSON.parse(result.stdout) : {};
        return {
            blocked: result.status === 2,
            reason: result.stderr.trim(),
            context: output.hookSpecificOutput?.additionalContext as string | undefined,
        };
    }

    function turnFor(sessionID: string) {
        const existing = turns.get(sessionID);
        if (existing) return existing;
        const turn: Turn = { id: null, revision: 0, checked: null, checking: false, correcting: false };
        // Reopening the harness keeps design state but requires fresh consent.
        check(sessionID, turn, "SessionStart", { source: "resume" });
        turns.set(sessionID, turn);
        return turn;
    }

    async function completed(sessionID: string) {
        const turn = turns.get(sessionID);
        if (!turn?.id || turn.checking || turn.correcting) return;
        turn.checking = true;
        const revision = turn.revision;
        try {
            const response = await client.session.messages({ path: { id: sessionID } });
            if (response.error || !response.data) throw new Error("agent-hooks: could not read completed turn");
            if (turn.revision !== revision || turns.get(sessionID) !== turn) return;
            const latest = response.data.at(-1);
            if (
                latest?.info.role !== "assistant" ||
                latest.info.parentID !== turn.id ||
                !latest.info.time?.completed ||
                latest.info.error ||
                latest.info.id === turn.checked
            )
                return;
            turn.checked = latest.info.id;
            const result = check(sessionID, turn, "Stop", {
                last_assistant_message: latest.parts
                    .filter((part) => part.type === "text" && !part.ignored)
                    .map((part) => part.text ?? "")
                    .join("\n"),
            });
            if (!result.blocked) return;
            // OpenCode has no blocking Stop hook. Request one correction after
            // completion, marked synthetic so it can never grant write consent.
            turn.correcting = true;
            const correction = await client.session.promptAsync({
                path: { id: sessionID },
                body: {
                    parts: [{ type: "text", text: result.reason, synthetic: true }],
                    agent: latest.info.agent,
                    ...(latest.info.providerID && latest.info.modelID
                        ? { model: { providerID: latest.info.providerID, modelID: latest.info.modelID } }
                        : {}),
                },
            });
            if (correction.error) throw new Error("agent-hooks: could not request the design-loop correction");
        } finally {
            turn.checking = false;
        }
    }

    return {
        "chat.message": async (input: { sessionID: string }, output: { message: { id: string }; parts: Part[] }) => {
            const turn = turnFor(input.sessionID);
            turn.id = output.message.id;
            turn.revision++;
            turn.checked = null;
            if (output.parts.some((part) => !part.synthetic && !part.ignored)) turn.correcting = false;
            check(input.sessionID, turn, "UserPromptSubmit", {
                prompt: output.parts
                    .filter((part) => part.type === "text" && !part.synthetic && !part.ignored)
                    .map((part) => part.text ?? "")
                    .join("\n"),
            });
        },
        "tool.execute.before": async (input: ToolInput, output: { args: Record<string, unknown> }) => {
            check(input.sessionID, turnFor(input.sessionID), "PreToolUse", normalizeTool(input.tool, output.args));
        },
        "tool.execute.after": async (
            input: ToolInput & { args: Record<string, unknown> },
            output: { metadata?: Record<string, unknown> },
        ) => {
            check(input.sessionID, turnFor(input.sessionID), "PostToolUse", {
                ...normalizeTool(input.tool, input.args),
                tool_response: { exit_code: output.metadata?.exit ?? 0 },
            });
        },
        "experimental.chat.system.transform": async (input: { sessionID?: string }, output: { system: string[] }) => {
            if (!input.sessionID) return;
            const result = check(input.sessionID, turnFor(input.sessionID), "SessionStart", { source: "compact" });
            if (result.context) output.system.push(result.context);
        },
        event: async ({
            event,
        }: {
            event: { type: string; properties: { sessionID?: string; info?: { id: string } } };
        }) => {
            const sessionID = event.properties.sessionID ?? event.properties.info?.id;
            if (!sessionID) return;
            // OpenCode does not await event listeners. Contain errors here so a
            // failed notification cannot become an unhandled promise rejection.
            try {
                if (event.type === "session.idle") await completed(sessionID);
                if (event.type === "session.error" || event.type === "session.deleted") {
                    const turn = turns.get(sessionID);
                    if (turn) {
                        check(sessionID, turn, "Interrupt");
                        turn.id = null;
                        turn.revision++;
                    }
                    if (event.type === "session.deleted") turns.delete(sessionID);
                }
            } catch (error) {
                console.error(error);
            }
        },
    };
}
