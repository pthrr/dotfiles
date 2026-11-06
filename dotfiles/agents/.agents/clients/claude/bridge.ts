/**
 * Claude Code's hook events for the gate. Claude Code sends the neutral event as
 * it is, except that it delivers its own notifications, a sub-agent's hand-back
 * included, as prompts with stable tags. None of them is the human's.
 */
import { run } from "../../hooks/gate/gate.ts";

const injected = /^<((task-notification|command-name|local-command-caveat|local-command-stdout)>|agent-message from=")/;

export function normalize(source: string): string {
    const input = JSON.parse(source);

    if (typeof input.prompt === "string" && injected.test(input.prompt)) {
        input.synthetic = true;
    }

    return JSON.stringify(input);
}

if (import.meta.main) {
    process.exitCode = run("claude", normalize);
}
