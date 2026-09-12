/** Exercise decisions through the JSON/stdin interface used by the harnesses. */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readdirSync, rmSync, symlinkSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { shellEffect } from "./shell-policy.ts";

const adapter = fileURLToPath(new URL("./adapter.ts", import.meta.url));
const render = `ITERATION 1
GOAL   Produce the result.

1 CODE ORGA
  src/example.ts  example

2 PRIMITIVES
  src/example.ts  uses  -
    :2  fn  example  ()
        !  deterministic

3 INTERACTION
  main example - direct sync -

DELTA  declared example
OPEN   -
`;

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

    scenario("read-only exploration works without consent; writes do not", (h) => {
        h.shell("git status --short; rg --files");
        h.patch("src/example.ts", 2);
        h.shell("printf content > src/example.ts", 2);
        h.prompt("please fix it");
        h.patch("src/example.ts", 2);
        h.hook("PreToolUse", 2, { tool_name: "Write", tool_input: { file_path: "PLAN.md" } });
    });

    scenario("consent covers a turn and resets on the next message", (h) => {
        for (const text of ["yes", "Y", "Ok, do it"]) {
            h.prompt(text);
            h.patch();
            h.patch("src/another.ts");
        }
        for (const text of ["what changed?", "yesterday", "okay", ""]) {
            h.prompt(text);
            h.patch("src/example.ts", 2);
        }
        h.prompt();
        h.patch("src/example.ts", 2, { session_id: "another-session" });
    });

    scenario("creating a plan cannot smuggle source edits in the same patch", (h) => {
        unlinkSync(join(h.root, "PLAN.md"));
        h.prompt();
        h.patch("PLAN.md");
        h.patch("src/example.ts", 2);
        h.hook("PreToolUse", 2, {
            tool_name: "apply_patch",
            tool_input: {
                command:
                    "*** Begin Patch\n*** Add File: PLAN.md\n+goal\n*** Add File: src/new.ts\n+code\n*** End Patch",
            },
        });
    });

    scenario("rename endpoints, deletions, and new paths use their own plan", (h) => {
        mkdirSync(join(h.root, "foreign/.git"), { recursive: true });
        h.prompt();
        for (const operation of [
            "*** Delete File: foreign/x.ts",
            "*** Update File: src/example.ts\n*** Move to: foreign/x.ts",
        ]) {
            h.hook("PreToolUse", 2, {
                tool_name: "apply_patch",
                tool_input: { command: `*** Begin Patch\n${operation}\n*** End Patch` },
            });
        }
        h.patch("brand/new/directory/file.ts");
    });

    scenario("symlinks do not borrow the source directory's plan", (h) => {
        mkdirSync(join(h.root, "foreign/.git"), { recursive: true });
        symlinkSync(join(h.root, "foreign"), join(h.root, "src/link"), "dir");
        h.prompt();
        h.patch("src/link/file.ts", 2);
    });

    scenario("Closed allows implementation; Finished re-arms the write gate", (h) => {
        h.prompt();
        h.plan("\n## Closed\n");
        h.patch();
        h.plan("\n## Closed\n\n## Finished\n");
        h.patch("src/example.ts", 2);
        h.patch("PLAN.md");
        const result = h.hook("SessionStart", 0, { source: "startup" });
        assert.match(result.stdout, /Produce the result/);
        assert.match(result.stdout, /Finished/);
    });

    scenario("shell commands require consent and a plan in their working directory", (h) => {
        mkdirSync(join(h.root, "foreign/.git"), { recursive: true });
        h.shell("node script.js", 2);
        h.prompt();
        h.shell("node script.js");
        h.shell("cd foreign && touch x", 2);
        h.hook("PreToolUse", 2, {
            tool_name: "Bash",
            tool_input: { command: "touch x", workdir: join(h.root, "foreign") },
        });
    });

    scenario("sed options after a print script require consent and a plan", (h) => {
        h.shell("sed -n 1p src/example.ts");
        h.shell("sed -n 1p -i src/example.ts", 2);
        h.prompt();
        unlinkSync(join(h.root, "PLAN.md"));
        h.shell("sed -n 1p -i src/example.ts", 2);
        h.plan();
        h.shell("sed -n 1p -i src/example.ts");
    });

    scenario("the render is required only after skill activation and writes", (h) => {
        h.prompt();
        h.patch();
        h.hook("Stop", 0, { last_assistant_message: "Done." });
        h.loadSkill();
        h.hook("Stop", 2, { last_assistant_message: "Done." });
        h.hook("Stop", 0, { last_assistant_message: render });
        h.hook("Stop", 2, { last_assistant_message: render.replace(":2", ":9999") });
        h.hook("Stop", 0, { stop_hook_active: true, last_assistant_message: "Done." });
        h.prompt("explain the design");
        h.hook("Stop", 0, { last_assistant_message: "Explanation only." });
    });

    scenario("shell mutations owe the same render", (h) => {
        h.prompt();
        h.loadSkill();
        h.shell("node edit.js");
        h.hook("Stop", 2, { last_assistant_message: "Done." });
    });

    scenario("closed plans and denied patches do not require renders", (h) => {
        h.plan("\n## Closed\n");
        h.prompt();
        h.loadSkill();
        h.patch();
        h.hook("Stop", 0, { last_assistant_message: "Done." });
        h.plan();
        h.prompt("discuss this");
        h.patch("src/example.ts", 2);
        h.hook("Stop", 0, { last_assistant_message: "Discussion." });
    });

    scenario("resume and compaction preserve design state; fresh sessions reset it", (h) => {
        h.prompt();
        h.loadSkill();
        const compact = h.hook("SessionStart", 0, { source: "compact" });
        assert.match(compact.stdout, /Produce the result/);
        assert.match(compact.stdout, /TypeScript, node:test/);
        h.patch();
        const resume = h.hook("SessionStart", 0, { source: "resume" });
        assert.match(resume.stdout, /ITERATION/);
        h.patch("src/example.ts", 2);
        h.hook("SessionStart", 0, { source: "clear" });
        h.prompt();
        h.patch();
        h.hook("Stop", 0, { last_assistant_message: "No active loop." });
    });

    scenario("the Skill tool activates the loop", (h) => {
        h.hook("SessionStart", 0, { source: "startup" });
        h.prompt();
        h.loadSkill();
        h.patch();
        h.hook("Stop", 2, { last_assistant_message: "Done." });
    });

    scenario("reading SKILL.md activates the loop only where reading is how skills load", (h) => {
        for (const read of [
            { tool_name: "Read", tool_input: { file_path: "/skills/software-design/SKILL.md" } },
            { tool_name: "Bash", tool_input: { command: "cat ~/.agents/skills/software-design/SKILL.md" } },
        ]) {
            h.hook("SessionStart", 0, { source: "startup" });
            h.prompt();
            h.hook("PostToolUse", 0, { ...read, tool_response: {} });
            h.patch();
            // Claude loads a skill through the Skill tool, so a read of the
            // file is ordinary access — editing the skill, grepping it — and
            // must not put the session in strict mode.
            h.hook("Stop", client === "claude" ? 0 : 2, { last_assistant_message: "Done." });
        }
    });

    scenario("failed skill reads do not activate the loop", (h) => {
        h.prompt();
        h.hook("PostToolUse", 0, {
            tool_name: "Bash",
            tool_input: { command: "cat ~/.agents/skills/software-design/SKILL.md" },
            tool_response: { exit_code: 1 },
        });
        h.patch();
        h.hook("Stop", 0, { last_assistant_message: "Done." });
    });

    scenario("malformed events and corrupted state fail closed", (h) => {
        h.hook("PreToolUse", 2, { tool_name: "apply_patch", tool_input: { command: "unparseable" } });
        h.hook("PreToolUse", 2, { tool_name: "Bash", tool_input: {} });
        h.hook("PreToolUse", 2, { session_id: null });
        h.prompt();
        const stateDir = join(h.root, "state/agent-hooks", client);
        for (const file of readdirSync(stateDir).filter((file) => file.endsWith(".json")))
            writeFileSync(join(stateDir, file), "{");
        h.patch("src/example.ts", 2);
    });

    if (client === "codex") {
        scenario("turn IDs and interruptions revoke old consent", (h) => {
            h.prompt();
            h.patch("src/example.ts", 2, { turn_id: "turn-2" });
            h.prompt();
            h.hook("Interrupt");
            h.patch("src/example.ts", 2);
        });

        scenario("explicit skill invocations activate; generated prompts never grant consent", (h) => {
            h.prompt("ok, $software-design");
            h.patch();
            const blocked = h.hook("Stop", 2, { last_assistant_message: "Done." });
            h.prompt(blocked.stderr.trim(), { turn_id: "turn-2" });
            h.patch("src/example.ts", 2, { turn_id: "turn-2" });
            h.prompt("ok", { turn_id: "turn-3" });
            h.patch("src/example.ts", 0, { turn_id: "turn-3" });
        });
    }
}

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
        // A backslash still escapes inside double quotes, the closing quote
        // included, so allowing it there would desync the scan.
        'cat "a\\b"',
        "cat a\\b",
        // sort is the one allowlisted reader that can be told to write.
        "sort -o out file",
        "sort -no out file",
        "sort --output=out file",
        "sort --o out file",
        "uniq in out",
        "env FOO=1 ls",
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
    const root = mkdtempSync(join(tmpdir(), "agent-hooks-test-"));
    mkdirSync(join(root, ".git"));
    mkdirSync(join(root, "src"));
    writeFileSync(join(root, "src/example.ts"), "// example\nfunction example() {\n}\n");
    function plan(suffix = "") {
        writeFileSync(
            join(root, "PLAN.md"),
            "## Done when\n\nProduce the result.\n\n## Stack\n\nTypeScript, node:test.\n" + suffix,
        );
    }
    plan();
    function hook(event: string, expected = 0, fields: Record<string, unknown> = {}) {
        const input = {
            session_id: "session",
            cwd: root,
            hook_event_name: event,
            ...(client !== "claude" ? { turn_id: "turn-1" } : {}),
            ...fields,
        };
        const result = spawnSync(process.execPath, ["--experimental-strip-types", adapter, client], {
            input: JSON.stringify(input),
            encoding: "utf8",
            timeout: 15_000,
            env: { ...process.env, XDG_STATE_HOME: join(root, "state") },
        });
        assert.equal(
            result.status,
            expected,
            `${client} ${event}: ${result.error ?? ""}\n${result.stdout}\n${result.stderr}`,
        );
        if (result.stdout) JSON.parse(result.stdout);
        return result;
    }
    return {
        root,
        plan,
        hook,
        prompt: (text = "ok", fields: Record<string, unknown> = {}) =>
            hook("UserPromptSubmit", 0, { prompt: text, ...fields }),
        patch: (path = "src/example.ts", expected = 0, fields: Record<string, unknown> = {}) =>
            hook("PreToolUse", expected, {
                tool_name: "apply_patch",
                tool_input: { command: `*** Begin Patch\n*** Update File: ${path}\n@@\n-old\n+new\n*** End Patch\n` },
                ...fields,
            }),
        shell: (command: string, expected = 0) =>
            hook("PreToolUse", expected, { tool_name: "Bash", tool_input: { command } }),
        // The Skill tool is the one load signal every client honours; reading
        // the file only counts where reading is how a skill loads.
        loadSkill: () =>
            hook("PostToolUse", 0, {
                tool_name: "Skill",
                tool_input: { skill: "software-design" },
                tool_response: {},
            }),
    };
}
