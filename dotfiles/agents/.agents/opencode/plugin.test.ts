import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import sharedHooks from "./plugin.ts";

type Context = Parameters<typeof sharedHooks>[0];
type History = NonNullable<Awaited<ReturnType<Context["client"]["session"]["messages"]>>["data"]>;
type Prompt = Parameters<Context["client"]["session"]["promptAsync"]>[0];

async function harness() {
    const root = mkdtempSync(join(tmpdir(), "opencode-hooks-test-"));
    const previousStateHome = process.env.XDG_STATE_HOME;
    process.env.XDG_STATE_HOME = join(root, "state");
    mkdirSync(join(root, ".git"));
    writeFileSync(join(root, "PLAN.md"), "## Done when\n\nProduce the result.\n\n## Stack\n\nTypeScript.\n");
    const corrections: Prompt[] = [];
    let history: History = [];
    let reading: (() => Promise<void>) | undefined;
    const context: Context = {
        directory: root,
        client: {
            session: {
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
    return {
        root,
        context,
        plugin,
        corrections,
        prompt: (text = "ok", id = "user-1", synthetic = false) =>
            plugin["chat.message"](
                { sessionID: "session" },
                { message: { id }, parts: [{ type: "text", text, synthetic }] },
            ),
        tool: (tool: string, args: Record<string, unknown>) =>
            plugin["tool.execute.before"]({ sessionID: "session", tool, callID: "call" }, { args }),
        skill: () =>
            plugin["tool.execute.after"](
                { sessionID: "session", tool: "skill", callID: "skill", args: { name: "software-design" } },
                { metadata: {} },
            ),
        finished: (options: { parentID?: string; error?: unknown; text?: string } = {}) => {
            history = [
                {
                    info: {
                        id: "assistant-1",
                        role: "assistant",
                        parentID: options.parentID ?? "user-1",
                        time: { completed: 1 },
                        error: options.error,
                        agent: "build",
                        providerID: "chosen-provider",
                        modelID: "chosen-model",
                    },
                    parts: [{ type: "text", text: options.text ?? "Done." }],
                },
            ];
        },
        onRead: (callback: () => Promise<void>) => (reading = callback),
        idle: () => plugin.event({ event: { type: "session.idle", properties: { sessionID: "session" } } }),
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

scenario("native write and shell tools require consent; reads remain available", async (h) => {
    await h.tool("read", { filePath: "PLAN.md" });
    await h.tool("shell", { command: "git status --short" });
    for (const tool of ["write", "edit", "multiedit"]) {
        await assert.rejects(h.tool(tool, { filePath: "new.ts" }), /not authorized/);
    }
    await assert.rejects(h.tool("shell", { command: "touch new.ts" }), /not authorized/);
    await assert.rejects(h.tool("execute", { code: "writeFile()" }), /not authorized/);
    await h.prompt();
    await h.tool("write", { filePath: "new.ts" });
    await h.tool("bash", { command: "touch new.ts" });
    await h.prompt("review it", "user-2");
    await assert.rejects(h.tool("edit", { filePath: "new.ts" }), /not authorized/);
});

scenario("patchText targets and shell workdirs keep their own plan checks", async (h) => {
    mkdirSync(join(h.root, "foreign/.git"), { recursive: true });
    await h.prompt();
    await h.tool("apply_patch", { patchText: "*** Begin Patch\n*** Add File: new.ts\n+code\n*** End Patch" });
    await assert.rejects(
        h.tool("apply_patch", {
            patchText: "*** Begin Patch\n*** Update File: new.ts\n*** Move to: foreign/new.ts\n*** End Patch",
        }),
        /no non-empty PLAN/,
    );
    await assert.rejects(
        h.tool("shell", { command: "touch new.ts", workdir: join(h.root, "foreign") }),
        /no non-empty PLAN/,
    );
    unlinkSync(join(h.root, "PLAN.md"));
    await assert.rejects(h.tool("write", { filePath: "new.ts" }), /no non-empty PLAN/);
    await h.tool("write", { filePath: "PLAN.md" });
});

scenario("synthetic and ignored text never grant consent", async (h) => {
    await h.prompt();
    await h.prompt("ok", "generated", true);
    await assert.rejects(h.tool("write", { filePath: "new.ts" }), /not authorized/);
    await h.plugin["chat.message"](
        { sessionID: "session" },
        { message: { id: "user-2" }, parts: [{ type: "text", text: "yes", ignored: true }] },
    );
    await assert.rejects(h.tool("write", { filePath: "new.ts" }), /not authorized/);
});

scenario("reopening a session preserves design context and revokes consent", async (h) => {
    await h.prompt();
    await h.skill();
    const reopened = await sharedHooks(h.context);
    const output = { system: [] as string[] };
    await reopened["experimental.chat.system.transform"]({ sessionID: "session" }, output);
    assert.match(output.system.join("\n"), /Produce the result/);
    await assert.rejects(
        reopened["tool.execute.before"](
            { sessionID: "session", tool: "write", callID: "call" },
            { args: { filePath: "new.ts" } },
        ),
        /not authorized/,
    );
});

scenario("completed writes request one synthetic correction with the existing model", async (h) => {
    await h.prompt();
    await h.skill();
    await h.tool("write", { filePath: "new.ts" });
    h.finished();
    await Promise.all([h.idle(), h.idle()]);
    assert.equal(h.corrections.length, 1);
    const correction = h.corrections[0];
    assert.equal(correction.body.parts[0].synthetic, true);
    assert.deepEqual(correction.body.model, { providerID: "chosen-provider", modelID: "chosen-model" });
    await h.prompt(correction.body.parts[0].text, "correction", true);
    await assert.rejects(h.tool("edit", { filePath: "new.ts" }), /not authorized/);
    h.finished({ parentID: "correction" });
    await h.idle();
    assert.equal(h.corrections.length, 1);
});

scenario("closed plans, failures, and stale completions do not request corrections", async (h) => {
    await h.prompt();
    await h.skill();
    await h.tool("write", { filePath: "new.ts" });
    h.finished({ error: { name: "MessageAbortedError" } });
    await h.idle();
    h.finished({ parentID: "previous-user" });
    await h.idle();
    writeFileSync(join(h.root, "PLAN.md"), "## Closed\n");
    h.finished();
    await h.idle();
    assert.equal(h.corrections.length, 0);
});

scenario("a newer prompt cancels an in-flight completion check", async (h) => {
    await h.prompt();
    await h.skill();
    await h.tool("write", { filePath: "new.ts" });
    h.finished();
    h.onRead(() => h.prompt("explain", "user-2"));
    await h.idle();
    assert.equal(h.corrections.length, 0);
});
