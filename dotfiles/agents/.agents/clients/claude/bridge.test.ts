/** The bridge marks Claude Code's injected prompts synthetic, and nothing else. */
import assert from "node:assert/strict";
import { test } from "node:test";
import { normalize } from "./bridge.ts";

const synthetic = (prompt: string) => JSON.parse(normalize(JSON.stringify({ prompt }))).synthetic;

test("injected notifications and sub-agent hand-backs are synthetic", () => {
    for (const prompt of [
        "<task-notification>done</task-notification>",
        "<command-name>/clear</command-name>",
        "<local-command-caveat>Caveat</local-command-caveat>",
        "<local-command-stdout>ok</local-command-stdout>",
        '<agent-message from="worker">\n[Subagent hand-back] Worker done.\n</agent-message>',
        '<agent-message from="worker">\nok\n</agent-message>',
    ]) {
        assert.equal(synthetic(prompt), true, prompt);
    }
});

test("human prompts stay as they are, tags inside them included", () => {
    for (const prompt of ["ok", "explain <task-notification>", ' <agent-message from="worker">', "<agent-message>"]) {
        assert.equal(synthetic(prompt), undefined, prompt);
    }

    assert.equal(normalize(JSON.stringify({ hook_event_name: "Stop" })), JSON.stringify({ hook_event_name: "Stop" }));
});
