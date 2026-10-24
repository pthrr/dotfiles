import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import sharedHooks from "./plugin.ts";

type Context = Parameters<typeof sharedHooks>[0];
type History = NonNullable<Awaited<ReturnType<Context["client"]["session"]["messages"]>>["data"]>;
type Prompt = Parameters<Context["client"]["session"]["promptAsync"]>[0];

const plan = `# New module

## Problem

The project needs a new module that produces the result.

## Changes

- \`new.ts\` — add the module and export the function that produces the result

## Verify

Run the plugin tests and check that every scenario passes.
`;

async function harness() {
    const root = mkdtempSync("/var/tmp/opencode-hooks-test-");
    const previousStateHome = process.env.XDG_STATE_HOME;
    process.env.XDG_STATE_HOME = join(root, "state");
    mkdirSync(join(root, ".git"));
    writeFileSync(join(root, "PLAN.md"), plan);
    const corrections: Prompt[] = [];
    const aborts: string[] = [];
    let abortFails = false;
    let history: History = [];
    let reading: (() => Promise<void>) | undefined;
    const context: Context = {
        directory: root,
        client: {
            session: {
                abort: async ({ path }) => {
                    aborts.push(path.id);
                    return abortFails ? { error: "unavailable" } : {};
                },
                messages: async () => {
                    await reading?.();
                    return { data: history };
                },
                promptAsync: async (request) => {
                    corrections.push(request);
                    return {};
                },
            },
        },
    };
    const plugin = await sharedHooks(context);
    const prompt = (text = "ok", id = "user-1", synthetic = false) =>
        plugin["chat.message"]({ sessionID: "session" }, { message: { id }, parts: [{ type: "text", text, synthetic }] });
    const finished = (options: { parentID?: string; error?: unknown; text?: string } = {}) => {
        const parentID = options.parentID ?? "user-1";
        history = [
            {
                info: {
                    id: `assistant-${parentID}`,
                    role: "assistant",
                    parentID,
                    time: { completed: 1 },
                    error: options.error,
                    agent: "build",
                    providerID: "chosen-provider",
                    modelID: "chosen-model",
                },
                parts: [{ type: "text", text: options.text ?? "Done." }],
            },
        ];
    };
    const idle = () => plugin.event({ event: { type: "session.idle", properties: { sessionID: "session" } } });
    return {
        root,
        context,
        plugin,
        corrections,
        aborts,
        failAbort: () => { abortFails = true; },
        prompt,
        finished,
        idle,
        // A turn that ends with the plan pasted in full: the one way it counts as shown.
        show: async (id = "user-0") => {
            await prompt("show me the plan", id);
            finished({ parentID: id, text: plan });
            await idle();
        },
        tool: (tool: string, args: Record<string, unknown>) =>
            plugin["tool.execute.before"]({ sessionID: "session", tool, callID: "call" }, { args }),
        after: (tool: string, args: Record<string, unknown>, exit = 0) =>
            plugin["tool.execute.after"]({ sessionID: "session", tool, callID: "call", args }, { metadata: { exit } }),
        onRead: (callback: () => Promise<void>) => (reading = callback),
        cleanup: () => {
            if (previousStateHome === undefined) delete process.env.XDG_STATE_HOME;
            else process.env.XDG_STATE_HOME = previousStateHome;
            rmSync(root, { recursive: true, force: true });
        },
    };
}

function scenario(name: string, check: (h: Awaited<ReturnType<typeof harness>>) => Promise<void>) {
    test(`OpenCode plugin: ${name}`, async () => {
        const h = await harness();
        try {
            await check(h);
        } finally {
            h.cleanup();
        }
    });
}

scenario("native writes require exact approval; reads remain available", async (h) => {
    await h.tool("read", { filePath: "PLAN.md" });
    await h.tool("shell", { command: "git status --short" });
    await assert.rejects(h.tool("write", { filePath: "new.ts" }), /not authorized/);
    await h.show();

    for (const text of ["yes", "OK", "ok do 1", "ok ", "is this ok?"]) {
        await h.prompt(text);
        await assert.rejects(h.tool("write", { filePath: "new.ts" }), /not authorized/);
    }

    await h.prompt();
    await h.tool("write", { filePath: "new.ts" });
    await h.after("write", { filePath: "new.ts" });
});

scenario("a question pauses writes and aborts a running mutation", async (h) => {
    await h.show();
    await h.prompt();
    await h.tool("bash", { command: "node build.js" });
    await h.prompt("what changed?", "question");
    assert.deepEqual(h.aborts, ["session"]);
    await h.tool("read", { filePath: "new.ts" });
    await assert.rejects(h.tool("write", { filePath: "new.ts" }), /not authorized/);
    await h.prompt("ok", "resume");
    await h.tool("write", { filePath: "new.ts" });
});

scenario("failed cancellation leaves implementation paused", async (h) => {
    await h.show();
    await h.prompt();
    await h.tool("bash", { command: "node build.js" });
    h.failAbort();
    await h.prompt("explain", "question");
    assert.equal(h.aborts.length, 1);
    await assert.rejects(h.tool("write", { filePath: "new.ts" }), /not authorized/);
});

scenario("read-only work does not request cancellation", async (h) => {
    await h.show();
    await h.prompt();
    await h.tool("bash", { command: "rg --files" });
    await h.prompt("explain", "question");
    assert.deepEqual(h.aborts, []);
});

scenario("a temporary working directory cannot exempt a shell mutation", async (h) => {
    await assert.rejects(h.tool("bash", { command: `touch ${h.root}/new.ts`, workdir: "/tmp" }), /not authorized/);
    await h.tool("write", { filePath: "/tmp/opencode-free-file.ts" });
    await h.show();
    await h.prompt();
    await h.tool("bash", { command: "node build.js", workdir: "/tmp" });
    await assert.rejects(h.tool("write", { filePath: "other.ts" }), /not listed under ## Changes/);
});

scenario("synthetic prompts preserve human state and cannot grant consent", async (h) => {
    await h.show();
    await h.prompt("ok", "generated", true);
    await assert.rejects(h.tool("write", { filePath: "new.ts" }), /not authorized/);
    await h.prompt();
    await h.prompt("synthetic context", "generated-2", true);
    await h.tool("write", { filePath: "new.ts" });
    await h.prompt("explain", "question");
    await h.prompt("ok", "generated-3", true);
    await assert.rejects(h.tool("write", { filePath: "new.ts" }), /not authorized/);
});

scenario("ordinary completion and unchanged re-presentation preserve the batch", async (h) => {
    await h.show();
    await h.prompt();
    await h.tool("write", { filePath: "new.ts" });
    await h.after("write", { filePath: "new.ts" });
    h.finished();
    await h.idle();
    assert.equal(h.corrections.length, 0);
    await h.tool("write", { filePath: "new.ts" });
    await h.prompt("ok", "another-ok");
    h.finished({ parentID: "another-ok", text: plan });
    await h.idle();
    await h.tool("write", { filePath: "new.ts" });
});

scenario("deletion closes the batch and identical recreation needs presentation", async (h) => {
    await h.show();
    await h.prompt();
    unlinkSync(join(h.root, "PLAN.md"));
    h.finished();
    await h.idle();
    writeFileSync(join(h.root, "PLAN.md"), plan);
    await h.prompt("ok", "old-ok");
    await assert.rejects(h.tool("write", { filePath: "new.ts" }), /approved proposal/);
    await h.show("new-presentation");
    await h.prompt("ok", "new-ok");
    await h.tool("write", { filePath: "new.ts" });
});

scenario("reopening and session errors pause consent", async (h) => {
    await h.show();
    await h.prompt();
    const reopened = await sharedHooks(h.context);
    await assert.rejects(reopened["tool.execute.before"](
        { sessionID: "session", tool: "write", callID: "call" }, { args: { filePath: "new.ts" } },
    ), /not authorized/);
    await h.prompt();
    await h.tool("write", { filePath: "new.ts" });
    await h.plugin.event({ event: { type: "session.error", properties: { sessionID: "session" } } });
    await assert.rejects(h.tool("write", { filePath: "new.ts" }), /not authorized/);
});

scenario("an unshown plan requests one correlated correction", async (h) => {
    await h.prompt("draft it");
    await h.tool("write", { filePath: "PLAN.md" });
    h.finished({ text: "Plan written." });
    await Promise.all([h.idle(), h.idle()]);
    assert.equal(h.corrections.length, 1);
    const correction = h.corrections[0];
    assert.equal(correction.body.parts[0].synthetic, true);
    assert.deepEqual(correction.body.model, { providerID: "chosen-provider", modelID: "chosen-model" });
    await h.prompt(correction.body.parts[0].text, "correction", true);
    h.finished({ parentID: "correction", text: plan });
    await h.idle();
    assert.equal(h.corrections.length, 1);
    await h.prompt("ok", "approval");
    await h.tool("write", { filePath: "new.ts" });
});

scenario("a newer human message cancels an in-flight completion check", async (h) => {
    await h.prompt("draft it");
    await h.tool("write", { filePath: "PLAN.md" });
    h.finished({ text: "Plan written." });
    h.onRead(() => h.prompt("explain", "question"));
    await h.idle();
    assert.equal(h.corrections.length, 0);
});
