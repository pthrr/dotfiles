/** OpenCode v1 bridge: human provenance, plan presentation, and cancellation. */
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { shellEffect } from "../hooks/shell-policy.ts";

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
            abort?(input: { path: { id: string } }): Promise<{ error?: unknown }>;
            promptAsync(input: {
                path: { id: string };
                body: { parts: Part[]; agent?: string; model?: { providerID: string; modelID: string } };
            }): Promise<{ error?: unknown }>;
        };
    };
};
type Turn = {
    id: string | null;
    revision: number;
    checked: string | null;
    checking: boolean;
    correction: "none" | "requested" | "running";
    feedback: string | null;
    inFlight: Set<string>;
    context: string[];
};
type ToolInput = { sessionID: string; tool: string; callID: string };
const adapter = fileURLToPath(new URL("../hooks/adapter.ts", import.meta.url));

function normalizeTool(tool: string, args: Record<string, unknown>): { tool_name: string; tool_input: Record<string, unknown> } {
    if (tool === "apply_patch") {
        return { tool_name: tool, tool_input: { command: args.patchText } };
    }

    if (tool === "bash" || tool === "shell") {
        return { tool_name: "Bash", tool_input: args };
    }

    if (tool === "execute") {
        return { tool_name: "Bash", tool_input: { command: "opencode-code-execution" } };
    }

    const names: Record<string, string> = { write: "Write", edit: "Edit", multiedit: "MultiEdit" };

    if (names[tool]) {
        return { tool_name: names[tool], tool_input: { file_path: args.filePath } };
    }

    return { tool_name: tool, tool_input: args };
}

export default async function sharedHooks({ directory, client }: Context) {
    const turns = new Map<string, Turn>();

    function check(sessionID: string, turn: Turn, event: string, fields: Record<string, unknown> = {}) {
        const result = spawnSync("node", ["--experimental-strip-types", adapter, "opencode"], {
            input: JSON.stringify({ session_id: sessionID, cwd: directory, hook_event_name: event, turn_id: turn.id, ...fields }),
            encoding: "utf8",
            timeout: 60_000,
            maxBuffer: 2 * 1024 * 1024,
        });

        if (result.error) {
            throw result.error;
        }

        if (result.status !== 0 && result.status !== 2) {
            throw new Error(`agent-hooks: adapter failed (${result.status}): ${result.stderr.trim()}`);
        }

        if (result.status === 2 && event !== "Stop") {
            throw new Error(result.stderr.trim() || "agent-hooks: blocked");
        }

        const output = result.stdout.trim() ? JSON.parse(result.stdout) : {};
        const context = output.hookSpecificOutput?.additionalContext;

        if (typeof context === "string" && context) {
            turn.context.push(context);
        }

        return { blocked: result.status === 2, reason: result.stderr.trim() };
    }

    function turnFor(sessionID: string) {
        const existing = turns.get(sessionID);

        if (existing) {
            return existing;
        }

        const turn: Turn = {
            id: null, revision: 0, checked: null, checking: false,
            correction: "none", feedback: null, inFlight: new Set(), context: [],
        };
        check(sessionID, turn, "SessionStart", { source: "resume" });
        turns.set(sessionID, turn);
        return turn;
    }

    async function completed(sessionID: string) {
        const turn = turns.get(sessionID);

        if (!turn?.id || turn.checking) {
            return;
        }

        turn.checking = true;
        const revision = turn.revision;

        try {
            const response = await client.session.messages({ path: { id: sessionID } });

            if (response.error || !response.data) {
                throw new Error("agent-hooks: could not read completed turn");
            }

            if (turn.revision !== revision || turns.get(sessionID) !== turn) {
                return;
            }

            const latest = response.data.at(-1);

            if (
                latest?.info.role !== "assistant" || latest.info.parentID !== turn.id ||
                !latest.info.time?.completed || latest.info.error || latest.info.id === turn.checked
            ) {
                return;
            }

            turn.checked = latest.info.id;
            const retry = turn.correction === "running";
            const result = check(sessionID, turn, "Stop", {
                last_assistant_message: latest.parts.filter((part) => part.type === "text" && !part.ignored).map((part) => part.text ?? "").join("\n"),
                ...(retry ? { stop_hook_active: true } : {}),
            });

            if (retry) {
                turn.correction = "none";
                turn.feedback = null;
            }

            if (!result.blocked || retry) {
                return;
            }

            turn.correction = "requested";
            turn.feedback = result.reason;
            const correction = await client.session.promptAsync({
                path: { id: sessionID },
                body: {
                    parts: [{ type: "text", text: result.reason, synthetic: true }],
                    agent: latest.info.agent,
                    ...(latest.info.providerID && latest.info.modelID ? {
                        model: { providerID: latest.info.providerID, modelID: latest.info.modelID },
                    } : {}),
                },
            });

            if (correction.error) {
                turn.correction = "none";
                turn.feedback = null;
                throw new Error("agent-hooks: could not request the plan correction");
            }
        } finally {
            turn.checking = false;
        }
    }

    return {
        "chat.message": async (input: { sessionID: string }, output: { message: { id: string }; parts: Part[] }) => {
            const turn = turnFor(input.sessionID);
            const human = output.parts.some((part) => !part.synthetic && !part.ignored);
            const allText = output.parts.filter((part) => part.type === "text" && !part.ignored).map((part) => part.text ?? "").join("\n");
            const text = output.parts.filter((part) => part.type === "text" && !part.synthetic && !part.ignored).map((part) => part.text ?? "").join("\n");
            const continuation = !human && turn.correction === "requested" && allText === turn.feedback;
            turn.id = output.message.id;
            turn.revision++;
            turn.checked = null;

            if (continuation) {
                turn.correction = "running";
            } else if (human) {
                turn.correction = "none";
                turn.feedback = null;
            }

            // Persist the pause before requesting abort. An unavailable or failed
            // abort cannot grant the old turn permission for another mutation.
            check(input.sessionID, turn, "UserPromptSubmit", {
                prompt: text,
                synthetic: !human,
                ...(continuation ? { continuation: true } : {}),
            });

            if (human && text !== "ok" && turn.inFlight.size && client.session.abort) {
                try {
                    const result = await client.session.abort({ path: { id: input.sessionID } });

                    if (result.error) {
                        console.error("agent-hooks: cancellation request failed; implementation remains paused.");
                    }
                } catch (error) {
                    console.error("agent-hooks: cancellation request failed; implementation remains paused.", error);
                }
            }
        },
        "tool.execute.before": async (input: ToolInput, output: { args: Record<string, unknown> }) => {
            const turn = turnFor(input.sessionID);
            const normalized = normalizeTool(input.tool, output.args);
            check(input.sessionID, turn, "PreToolUse", { ...normalized, tool_use_id: input.callID });
            const command = normalized.tool_input.command;
            const mutating = normalized.tool_name === "Bash"
                ? typeof command === "string" && !shellEffect(command, directory).readonly
                : ["Write", "Edit", "MultiEdit", "apply_patch"].includes(normalized.tool_name);

            if (mutating) {
                turn.inFlight.add(input.callID);
            }
        },
        "tool.execute.after": async (input: ToolInput & { args: Record<string, unknown> }, output: { metadata?: Record<string, unknown> }) => {
            const turn = turnFor(input.sessionID);
            turn.inFlight.delete(input.callID);
            check(input.sessionID, turn, "PostToolUse", {
                ...normalizeTool(input.tool, input.args),
                tool_use_id: input.callID,
                tool_response: { exit_code: output.metadata?.exit ?? 0 },
            });
        },
        "experimental.chat.system.transform": async (input: { sessionID?: string }, output: { system: string[] }) => {
            if (input.sessionID) {
                const turn = turnFor(input.sessionID);
                output.system.push(...turn.context.splice(0));
            }
        },
        event: async ({ event }: { event: { type: string; properties: { sessionID?: string; info?: { id: string } } } }) => {
            const sessionID = event.properties.sessionID ?? event.properties.info?.id;

            if (!sessionID) {
                return;
            }

            try {
                if (event.type === "session.idle") {
                    await completed(sessionID);
                }

                if (event.type === "session.error" || event.type === "session.deleted") {
                    const turn = turns.get(sessionID);

                    if (turn) {
                        check(sessionID, turn, "Interrupt");
                        turn.id = null;
                        turn.revision++;
                        turn.inFlight.clear();
                    }

                    if (event.type === "session.deleted") {
                        turns.delete(sessionID);
                    }
                }
            } catch (error) {
                console.error(error);
            }
        },
    };
}
