/** Exercise decisions through the JSON/stdin interface used by the harnesses. */
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import {
    existsSync,
    mkdirSync,
    mkdtempSync,
    readFileSync,
    readdirSync,
    rmSync,
    symlinkSync,
    unlinkSync,
    writeFileSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { shellEffect } from "./shell-policy.ts";

const adapter = fileURLToPath(new URL("./adapter.ts", import.meta.url));
const plan = `# Example

## Problem

The example module needs a function that produces the result.

## Changes

- \`src/example.ts\` — declare example() and make it produce the result
- \`src/another.ts\` — a second module the consent scenarios edit alongside it
- \`brand/\` — new directories the path scenarios create anywhere under it

## Verify

Run the adapter tests and check that every scenario passes.
`;
const revised = plan.replace("produce the result", "produce the result, memoized");

for (const client of ["claude", "codex", "opencode"] as const) {
    function scenario(name: string, check: (h: ReturnType<typeof harness>) => void) {
        test(`${client}: ${name}`, () => {
            const h = harness(client);

            try {
                check(h);
            } finally {
                rmSync(h.root, { recursive: true, force: true });
            }
        });
    }

    scenario("reads stay free and protected writes require consent", (h) => {
        h.shell("git status --short; rg --files");
        h.patch("src/example.ts", 2);
        h.shell("printf content > src/example.ts", 2);
        h.hook("PreToolUse", 0, { tool_name: "Write", tool_input: { file_path: "PLAN.md" } });
    });

    scenario("only the exact human message ok approves a shown plan", (h) => {
        h.present();

        for (const text of ["yes", "y", "OK", "Ok", "ok ", " ok", "ok\n", "ok do 1 and 2", "is this ok?", "not ok", ""]) {
            h.prompt(text);
            h.patch("src/example.ts", 2);
        }

        h.prompt("ok");
        h.patch();
    });

    scenario("questions pause the batch, allow reads, and request cancellation", (h) => {
        h.ready();
        h.patch();
        const id = h.state().proposal.id;
        const pause = h.prompt("what changed?");
        assert.match(pause.stdout, /cancellation/);
        h.shell("cat src/example.ts");
        h.patch("src/example.ts", 2);
        h.hook("Stop", 0, { last_assistant_message: "Here is the explanation." });
        h.prompt();
        assert.equal(h.state().proposal.id, id);
        h.patch();
    });

    scenario("ordinary turn endings and re-presentation preserve approval", (h) => {
        h.ready();
        h.patch();
        const id = h.state().proposal.id;
        h.hook("Stop", 0, { last_assistant_message: "The first part is done." });
        h.patch("src/another.ts");
        h.present();
        assert.equal(h.state().proposal.id, id);
        h.patch();
        h.shell("rm PLAN.md");
    });

    scenario("an ok cannot approve a plan presented later", (h) => {
        h.prompt();
        h.patch("src/example.ts", 2);
        h.present();
        h.patch("src/example.ts", 2);
        h.prompt();
        h.patch();
    });

    scenario("a revision or restored old content requires presentation and a fresh ok", (h) => {
        h.ready();
        const id = h.state().proposal.id;
        h.revise(revised);
        h.patch("src/example.ts", 2);
        h.revise(plan);
        h.patch("src/example.ts", 2);
        h.present();
        h.patch("src/example.ts", 2);
        h.prompt();
        h.patch();
        assert.notEqual(h.state().proposal.id, id);
    });

    scenario("showing a second proposal does not approve the first", (h) => {
        h.present();
        const other = join(h.root, "other/PLAN.md");
        mkdirSync(join(h.root, "other/src"), { recursive: true });
        const otherPlan = plan.replace("# Example", "# Second proposal");
        h.hook("PreToolUse", 0, { tool_name: "Write", tool_input: { file_path: other } });
        writeFileSync(other, otherPlan);
        h.hook("Stop", 0, { last_assistant_message: otherPlan });
        h.prompt();
        h.patch("src/example.ts", 2);
        h.patch("other/src/example.ts");
    });

    scenario("multiple proposals cannot be selected by one ok", (h) => {
        h.present();
        const other = join(h.root, "other/PLAN.md");
        mkdirSync(join(h.root, "other"));
        const otherPlan = plan.replace("# Example", "# Second proposal");
        h.hook("PreToolUse", 0, { tool_name: "Write", tool_input: { file_path: other } });
        writeFileSync(other, otherPlan);
        h.hook("Stop", 2, { last_assistant_message: `${plan}\n${otherPlan}` });
        h.prompt();
        h.patch("src/example.ts", 2);
    });

    scenario("ambiguous correction retries clear an earlier approval", (h) => {
        h.ready();
        const other = join(h.root, "other/PLAN.md");
        mkdirSync(join(h.root, "other"));
        const otherPlan = plan.replace("# Example", "# Second proposal");
        h.hook("PreToolUse", 0, { tool_name: "Write", tool_input: { file_path: other } });
        writeFileSync(other, otherPlan);
        h.hook("Stop", 0, { last_assistant_message: `${plan}\n${otherPlan}`, stop_hook_active: true });
        assert.equal(h.state().proposal, null);
        h.patch("src/example.ts", 2);
        h.prompt();
        h.patch("src/example.ts", 2);
    });

    scenario("deletion closes permanently and recreation needs a new proposal", (h) => {
        h.ready();
        const id = h.state().proposal.id;
        h.patch();
        unlinkSync(join(h.root, "PLAN.md"));
        h.hook("Stop", 0, { last_assistant_message: "Closed." });
        assert.equal(h.state().proposal, null);
        h.plan();
        h.prompt();
        h.patch("src/example.ts", 2);
        h.present();
        h.patch("src/example.ts", 2);
        h.prompt();
        h.patch();
        assert.notEqual(h.state().proposal.id, id);
    });

    scenario("deletion and recreation between events cannot reuse approval", (h) => {
        h.ready();
        unlinkSync(join(h.root, "PLAN.md"));
        h.plan();
        h.patch("src/example.ts", 2);
    });

    scenario("successful patch deletion closes even if a replacement already exists", (h) => {
        h.ready();
        const command = "*** Begin Patch\n*** Delete File: PLAN.md\n*** End Patch";
        h.hook("PreToolUse", 0, { tool_name: "apply_patch", tool_input: { command } });
        h.hook("PostToolUse", 0, { tool_name: "apply_patch", tool_input: { command }, tool_response: { exit_code: 0 } });
        assert.equal(h.state().proposal, null);
        h.patch("src/example.ts", 2);
    });

    scenario("a failed deletion preserves an unchanged open proposal", (h) => {
        h.ready();
        const command = "*** Begin Patch\n*** Delete File: PLAN.md\n*** End Patch";
        h.hook("PreToolUse", 0, { tool_name: "apply_patch", tool_input: { command } });
        h.hook("PostToolUse", 0, { tool_name: "apply_patch", tool_input: { command }, tool_response: { exit_code: 1 } });
        h.patch();
    });

    scenario("direct writes check every patch target and the listed file scope", (h) => {
        h.ready();
        h.patch("src/unlisted.ts", 2);
        h.patch("brand/new/file.ts");
        h.hook("PreToolUse", 2, {
            tool_name: "apply_patch",
            tool_input: { command: "*** Begin Patch\n*** Update File: PLAN.md\n+x\n*** Update File: src/unlisted.ts\n+y\n*** End Patch" },
        });
        assert.deepEqual(h.state().plansWritten, []);
    });

    scenario("temporary targets are free but their neighboring directories are gated", (h) => {
        h.prompt("explain");

        for (const path of ["/tmp/probe", "/tmp/ordinary/project/probe", join(homedir(), "tmp/probe"), join(homedir(), "tmp/project/probe")]) {
            h.hook("PreToolUse", 0, { tool_name: "Write", tool_input: { file_path: path } });
        }

        for (const path of ["/tmp-other/probe", join(homedir(), "tmp-other/probe")]) {
            h.hook("PreToolUse", 2, { tool_name: "Write", tool_input: { file_path: path } });
        }
    });

    scenario("symlinks use the actual destination rather than the temporary alias", (h) => {
        const scratch = mkdtempSync("/tmp/agent-hook-alias-");

        try {
            symlinkSync(join(h.root, "src"), join(scratch, "project"), "dir");
            h.hook("PreToolUse", 2, { tool_name: "Write", tool_input: { file_path: join(scratch, "project/example.ts") } });
            symlinkSync(scratch, join(h.root, "src/scratch"), "dir");
            h.patch("src/scratch/probe");
        } finally {
            rmSync(scratch, { recursive: true, force: true });
        }
    });

    scenario("a shell working directory grants no exemption", (h) => {
        h.prompt("explain");

        for (const workdir of ["/tmp", join(homedir(), "tmp"), join(homedir(), ".claude")]) {
            h.hook("PreToolUse", 2, { tool_name: "Bash", tool_input: { command: `touch ${h.root}/src/example.ts`, workdir } });
        }

        h.present();
        h.prompt();
        h.hook("PreToolUse", 0, { tool_name: "Bash", tool_input: { command: "node build.js", workdir: "/tmp" } });
    });

    scenario("synthetic events neither displace nor forge human approval", (h) => {
        h.ready();
        h.hook("UserPromptSubmit", 0, { prompt: "synthetic context", synthetic: true });
        h.patch();
        h.prompt("explain");
        h.hook("UserPromptSubmit", 0, { prompt: "ok", synthetic: true });
        h.patch("src/example.ts", 2);
        h.prompt("<local-command-stdout>ok</local-command-stdout>");
        h.patch("src/example.ts", 2);
    });

    scenario("draft plans must be shown, but retries never loop", (h) => {
        h.prompt("draft it");
        h.revise(revised);
        h.hook("Stop", 2, { last_assistant_message: "Plan written." });
        h.hook("Stop", 0, { last_assistant_message: revised, stop_hook_active: true });
        h.prompt();
        h.patch();
    });

    scenario("resume pauses, compaction preserves, and clear forgets approval", (h) => {
        h.ready();
        h.hook("SessionStart", 0, { source: "compact" });
        h.patch();
        h.hook("SessionStart", 0, { source: "resume" });
        h.patch("src/example.ts", 2);
        h.prompt();
        h.patch();
        h.hook("SessionStart", 0, { source: "clear" });
        h.prompt();
        h.patch("src/example.ts", 2);
    });

    scenario("old presentation-history state does not migrate approval", (h) => {
        h.ready();
        const stateDir = join(h.root, "state/agent-hooks", client);
        const file = readdirSync(stateDir).find((value) => value.endsWith(".json"))!;
        writeFileSync(join(stateDir, file), JSON.stringify({ prompt: "ok", active: true, touched: [], rules: [] }));
        h.patch("src/example.ts", 2);
        h.present();
        h.prompt();
        h.patch();
    });

    scenario("rules still fire once on a successful direct write", (h) => {
        const event = { tool_name: "Write", tool_input: { file_path: join(h.root, "src/lib.rs") } };
        assert.equal(h.hook("PostToolUse", 0, { ...event, tool_response: { exit_code: 1 } }).stdout, "");
        const output = h.hook("PostToolUse", 0, event).stdout;
        assert.match(output, /pub\(crate\)/);
        assert.doesNotMatch(output, /when:/);
        assert.equal(h.hook("PostToolUse", 0, event).stdout, "");
    });

    scenario("malformed events fail closed", (h) => {
        h.hook("PreToolUse", 2, { tool_name: "apply_patch", tool_input: { command: "unparseable" } });
        h.hook("PreToolUse", 2, { tool_name: "Bash", tool_input: {} });
        h.hook("PreToolUse", 2, { session_id: null });
    });

    if (client === "codex") {
        scenario("stale calls and posts cannot replace the latest human turn", (h) => {
            h.ready();
            h.prompt("ok", { turn_id: "new-turn" });
            h.hook("PostToolUse", 0, { tool_name: "Bash", tool_input: { command: "node build.js" }, turn_id: "turn-1" });
            h.patch("src/example.ts", 2, { turn_id: "turn-1" });
            h.patch("src/example.ts", 0, { turn_id: "new-turn" });
        });

        scenario("only exact correlated Stop feedback continues consent", (h) => {
            h.ready();
            h.hook("PreToolUse", 0, { tool_name: "Write", tool_input: { file_path: "PLAN.md" } });
            const held = h.hook("Stop", 2, { last_assistant_message: "Plan written." });
            h.prompt(held.stderr.trim(), { turn_id: "turn-2" });
            h.patch("src/example.ts", 0, { turn_id: "turn-2" });
            h.hook("Stop", 2, { last_assistant_message: "Plan written.", turn_id: "turn-2" });
            const feedback = h.state().stopFeedback;
            h.prompt(`${feedback}\nok`, { turn_id: "turn-3" });
            h.patch("src/example.ts", 2, { turn_id: "turn-3" });
        });
    }
}

test("a human question revokes an approval check already running under the lock", async () => {
    const h = harness("codex");
    const barrier = join(h.root, "hash-started");
    const release = join(h.root, "release-hash");
    const toolsDirectory = join(h.root, "bin");
    mkdirSync(toolsDirectory);
    const actualHash = spawnSync("which", ["sha256sum"], { encoding: "utf8" }).stdout.trim();
    assert.ok(actualHash);
    writeFileSync(join(toolsDirectory, "sha256sum"), `#!/usr/bin/env bash
printf ready > '${barrier}'
while [ ! -e '${release}' ]; do sleep 0.01; done
exec '${actualHash}' "$@"
`, { mode: 0o700 });
    h.ready();

    function launch(event: string, fields: Record<string, unknown>, slow = false) {
        const process = spawn(globalThis.process.execPath, ["--experimental-strip-types", adapter, "codex"], {
            cwd: h.root,
            env: {
                ...globalThis.process.env,
                XDG_STATE_HOME: join(h.root, "state"),
                ...(slow ? { PATH: `${toolsDirectory}:${globalThis.process.env.PATH}` } : {}),
            },
        });
        let stderr = "";
        process.stderr.on("data", (data) => { stderr += data; });
        process.stdout.resume();
        const done = new Promise<{ code: number | null; stderr: string }>((resolve, reject) => {
            process.on("error", reject);
            process.on("close", (code) => resolve({ code, stderr }));
        });
        process.stdin.end(JSON.stringify({ session_id: "session", cwd: h.root, hook_event_name: event, turn_id: "turn-1", ...fields }));
        return { process, done };
    }

    async function until(check: () => boolean) {
        const deadline = Date.now() + 10_000;

        while (!check()) {
            assert.ok(Date.now() < deadline, "timed out waiting for the approval boundary");
            await new Promise((resolve) => setTimeout(resolve, 10));
        }
    }

    const mutation = launch("PreToolUse", { tool_name: "Bash", tool_input: { command: "node build.js" } }, true);
    let question: ReturnType<typeof launch> | undefined;

    try {
        await until(() => existsSync(barrier));
        question = launch("UserPromptSubmit", { prompt: "explain", turn_id: "question" });
        const directory = join(h.root, "state/agent-hooks/codex");
        const journal = join(directory, readdirSync(directory).find((file) => file.endsWith(".human"))!);
        await until(() => JSON.parse(readFileSync(journal, "utf8")).prompt === "explain");
        writeFileSync(release, "continue");
        const denied = await mutation.done;
        assert.equal(denied.code, 2, denied.stderr);
        assert.match(denied.stderr, /superseded/);
        assert.equal((await question.done).code, 0);
        h.patch("src/example.ts", 2);
    } finally {
        writeFileSync(release, "continue");
        mutation.process.kill();
        question?.process.kill();
        rmSync(h.root, { recursive: true, force: true });
    }
});

test("Stop and read-only tools survive unavailable hook storage", () => {
    const root = mkdtempSync(join(tmpdir(), "agent-hooks-storage-test-"));
    try {
        const blocker = join(root, "state-blocker");
        writeFileSync(blocker, "not a directory");
        const invoke = (event: string, fields: Record<string, unknown> = {}) =>
            spawnSync(process.execPath, ["--experimental-strip-types", adapter, "claude"], {
                input: JSON.stringify({ session_id: "session", cwd: root, hook_event_name: event, ...fields }),
                encoding: "utf8",
                timeout: 15_000,
                env: { ...process.env, XDG_STATE_HOME: blocker },
            });

        // A broken stop check must let the turn end rather than trap it.
        const stop = invoke("Stop", { last_assistant_message: "Done." });
        assert.equal(stop.status, 0, stop.stderr);
        assert.match(stop.stderr, /stop check unavailable/);

        const read = invoke("PreToolUse", { tool_name: "Bash", tool_input: { command: "rg --files" } });
        assert.equal(read.status, 0, read.stderr);
        assert.equal(read.stderr, "");

        const write = invoke("PreToolUse", { tool_name: "Bash", tool_input: { command: "touch file" } });
        assert.equal(write.status, 2, write.stderr);

        const freePlan = invoke("PreToolUse", { tool_name: "Write", tool_input: { file_path: join(root, "PLAN.md") } });
        assert.equal(freePlan.status, 0, freePlan.stderr);
    } finally {
        rmSync(root, { recursive: true, force: true });
    }
});

test("shell allowlist accepts common read-only exploration", () => {
    for (const command of [
        "pwd",
        "ls -la",
        "git diff --stat",
        "git -C /tmp status --short",
        "rg --files --hidden",
        "cat README.md | head -20",
        "sed -n '1,80p' source.ts",
        "sed -n 1p first.ts second.ts",
        "sed -n 1p -- -i",
        "sed -n 1p -- *.ts",
        "cd src && cat example.ts",
        "git status\nrg --files",
        // A backslash is literal inside single quotes, which is where a regex
        // escape lives. Rejecting it outright sent every such grep to consent.
        "grep -nE 'SKILL\\.md|software-design' hooks.ts",
        "grep -n 'step 0\\|Step 0' a.sh",
        "rg '\\bTODO\\b' src",
        "printf '%s\\n' hi",
        "ls -la a; echo hi; ls -la b",
        "cmp a b",
        "md5sum a b",
        "diff -u a b",
        "dirname /a/b",
        "cut -f1 a",
        "tr -d x",
        "sort -n file",
        "sort -rn file",
    ]) {
        assert.equal(shellEffect(command, "/tmp").readonly, true, command);
    }
});

test("compound commands and potential shell side effects require consent", () => {
    for (const command of [
        "ls; touch x",
        "cat README.md\nrm x",
        "cat x > y",
        "cat x 2>/tmp/error",
        "cat $(touch x)",
        "cat `touch x`",
        "cat <(touch x)",
        "ls & touch x",
        "sed -i s/a/b/ x",
        "sed -n '1e touch x' x",
        "rg --pre=script pattern",
        "git diff --output=x",
        "git -c alias.x=whatever x",
        "./cat x",
        "node -e 'console.log(1)'",
        "bash -c 'ls'",
        "find . -delete",
        "awk 'BEGIN {system(\"touch x\")}'",
        // Unquoted, a backslash could escape anything, so the scan refuses rather
        // than guess. Inside double quotes it is handled instead — `\"` and `\\`
        // consume the pair and stay in sync, and every other backslash is literal
        // text, which is where regex escapes live. So `cat "a\b"` reads a file named
        // a\b, is read-only, and is deliberately not listed here.
        "cat a\\b",
        // sort is the one allowlisted reader that can be told to write.
        "sort -o out file",
        "sort -no out file",
        "sort --output=out file",
        "sort --o out file",
        "uniq in out",
        "env FOO=1 ls",
        "printf -v PATH /tmp; cat file",
    ]) {
        assert.equal(shellEffect(command, "/tmp").readonly, false, command);
    }
});

test("sed rejects trailing write options and operands that can expand into options", () => {
    for (const command of [
        "sed -n 1p -i sample.txt",
        "sed -n 1p sample.txt -i",
        "sed -n 1p -i.bak sample.txt",
        "sed -n 1p --in-place sample.txt",
        "sed -n 1p -e 'w written.txt' sample.txt",
        "sed -n 1p --expression='w written.txt' sample.txt",
        "sed -n 1p -e 'e touch written.txt' sample.txt",
        "sed -n 1p -f script.sed sample.txt",
        "sed -n 1p --file=script.sed sample.txt",
        "sed -n 1p *",
        "sed -n 1p ?i sample.txt",
        "sed -n 1p [-]i sample.txt",
        "sed -n 1p {sample.txt,-i}",
    ]) {
        assert.equal(shellEffect(command, "/tmp").readonly, false, command);
    }
});

function harness(client: "claude" | "codex" | "opencode") {
    // Protected project checks must run outside the exempt /tmp and ~/tmp trees.
    const root = mkdtempSync("/var/tmp/agent-hooks-test-");
    mkdirSync(join(root, ".git"));
    mkdirSync(join(root, "src"));
    writeFileSync(join(root, "src/example.ts"), "// example\nfunction example() {\n}\n");
    // A fixture rule, so the rules scenarios do not depend on what is installed.
    mkdirSync(join(root, "rules"));
    writeFileSync(
        join(root, "rules/rust.md"),
        '---\nwhen: "*.rs"\n---\n\n# Rust\n\n- `pub(crate)` shares code; it does not expose a boundary.\n',
    );
    const planFile = join(root, "PLAN.md");
    function writePlan(text = plan) {
        writeFileSync(planFile, text);
    }
    writePlan();
    function hook(event: string, expected = 0, fields: Record<string, unknown> = {}) {
        const input = {
            session_id: "session",
            cwd: root,
            hook_event_name: event,
            ...(client !== "claude" ? { turn_id: "turn-1" } : {}),
            ...fields,
        };
        // Run in the project root, as the harnesses do.
        const result = spawnSync(process.execPath, ["--experimental-strip-types", adapter, client], {
            input: JSON.stringify(input),
            cwd: root,
            encoding: "utf8",
            timeout: 15_000,
            env: { ...process.env, XDG_STATE_HOME: join(root, "state"), AGENT_RULES_DIR: join(root, "rules") },
        });
        assert.equal(
            result.status,
            expected,
            `${client} ${event}: ${result.error ?? ""}\n${result.stdout}\n${result.stderr}`,
        );
        if (result.stdout) JSON.parse(result.stdout);
        return result;
    }
    const prompt = (text = "ok", fields: Record<string, unknown> = {}) =>
        hook("UserPromptSubmit", 0, { prompt: text, ...fields });
    // End a turn with the plan on disk pasted in full: the one way it counts as shown.
    const present = () => hook("Stop", 0, { last_assistant_message: readFileSync(planFile, "utf8") });
    return {
        root,
        state: () => JSON.parse(readFileSync(join(root, "state/agent-hooks", client, readdirSync(join(root, "state/agent-hooks", client)).find((file) => file.endsWith(".json"))!), "utf8")),
        // Change the plan on disk behind the hooks' back.
        plan: writePlan,
        // Change it the way an agent does: a write the gate sees, then the file.
        revise: (text: string) => {
            hook("PreToolUse", 0, { tool_name: "Write", tool_input: { file_path: planFile } });
            writePlan(text);
        },
        hook,
        prompt,
        present,
        // A plan shown, then the user's ok: where every change starts.
        ready: () => {
            present();
            prompt();
        },
        patch: (path = "src/example.ts", expected = 0, fields: Record<string, unknown> = {}) =>
            hook("PreToolUse", expected, {
                tool_name: "apply_patch",
                tool_input: { command: `*** Begin Patch\n*** Update File: ${path}\n@@\n-old\n+new\n*** End Patch\n` },
                ...fields,
            }),
        shell: (command: string, expected = 0) =>
            hook("PreToolUse", expected, { tool_name: "Bash", tool_input: { command } }),
    };
}
