/** Exercise rule delivery through the JSON/stdin interface used by the harnesses. */
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const rules = fileURLToPath(new URL("./rules.ts", import.meta.url));

function scenario(name: string, check: (h: ReturnType<typeof harness>) => void) {
    test(name, () => {
        const h = harness();

        try {
            check(h);
        } finally {
            rmSync(h.root, { recursive: true, force: true });
        }
    });
}

scenario("rules fire once on a successful direct write", (h) => {
    const event = { tool_name: "Write", tool_input: { file_path: join(h.root, "src/lib.rs") } };
    assert.equal(h.hook("PostToolUse", { ...event, tool_response: { exit_code: 1 } }).stdout, "");
    const output = h.hook("PostToolUse", event).stdout;
    assert.match(output, /pub\(crate\)/);
    assert.doesNotMatch(output, /when:/);
    assert.equal(h.hook("PostToolUse", event).stdout, "");
});

scenario("rules read a when value wrapped onto indented lines", (h) => {
    const event = { tool_name: "Write", tool_input: { file_path: join(h.root, "src/main.zig") } };
    assert.match(h.hook("PostToolUse", event).stdout, /Globs continue on indented lines/);
});

scenario("rules fire once when a matching file is read", (h) => {
    const event = { tool_name: "Read", tool_input: { file_path: join(h.root, "flake.nix") } };
    const output = h.hook("PostToolUse", event).stdout;
    assert.match(output, /bounded memory/);
    assert.doesNotMatch(output, /commands:/);
    assert.equal(h.hook("PostToolUse", event).stdout, "");
});

scenario("rules fire when a shell command reads a matching file", (h) => {
    const command = (text: string) => ({ tool_name: "Bash", tool_input: { command: text } });
    assert.equal(h.hook("PostToolUse", command("grep -n bounded flake.nix")).stdout, "");
    assert.equal(h.hook("PostToolUseFailure", command("cat flake.nix")).stdout, "");
    assert.match(h.hook("PostToolUse", command("cat flake.nix")).stdout, /bounded memory/);
    assert.match(h.hook("PostToolUse", command("cd src && sed -n '1,20p' lib.rs")).stdout, /pub\(crate\)/);
});

scenario("rules fire once when a command runs a listed program", (h) => {
    const command = (text: string) => ({ tool_name: "Bash", tool_input: { command: text } });
    assert.equal(h.hook("PostToolUse", command("echo nixos /nix/store/x")).stdout, "");
    const nix = command("cd /tmp && /run/current-system/sw/bin/nix build");
    assert.match(h.hook("PostToolUse", nix).stdout, /bounded memory/);
    assert.equal(h.hook("PostToolUse", command("nixos-rebuild build")).stdout, "");
});

scenario("rules fire for every way a command can run a listed program", (h) => {
    const commands = [
        "cd /tmp && /run/current-system/sw/bin/nix build",
        "echo $(nix eval .#x)",
        "true;nix build",
        "echo start\nnix build",
        "sh -c 'nix build'",
        'ssh host "nixos-rebuild switch"',
    ];

    // A session apiece: a rule fires once per session, which would hide a miss.
    for (const [index, command] of commands.entries()) {
        const event = { session_id: `command-${index}`, tool_name: "Bash", tool_input: { command } };
        assert.match(h.hook("PostToolUse", event).stdout, /bounded memory/, command);
    }
});

scenario("a failing command loads rules, a failed read does not", (h) => {
    const read = { tool_name: "Read", tool_input: { file_path: join(h.root, "flake.nix") } };
    assert.equal(h.hook("PostToolUseFailure", read).stdout, "");
    assert.equal(h.hook("PostToolUse", { ...read, tool_response: { is_error: true } }).stdout, "");
    const command = { tool_name: "Bash", tool_input: { command: "nix build" } };
    assert.match(h.hook("PostToolUseFailure", command).stdout, /bounded memory/);
    const failed = { ...command, session_id: "exit-code", tool_response: { exit_code: 1 } };
    assert.match(h.hook("PostToolUse", failed).stdout, /bounded memory/);
});

scenario("each sub-agent is shown a rule once, apart from the lead", (h) => {
    const read = { tool_name: "Read", tool_input: { file_path: join(h.root, "flake.nix") } };
    assert.match(h.hook("PostToolUse", read).stdout, /bounded memory/);
    assert.match(h.hook("PostToolUse", { ...read, agent_id: "worker" }).stdout, /bounded memory/);
    assert.equal(h.hook("PostToolUse", { ...read, agent_id: "worker" }).stdout, "");
    assert.equal(h.hook("PostToolUse", read).stdout, "");
});

scenario("compaction and a new session show the rules again, resuming does not", (h) => {
    const read = { tool_name: "Read", tool_input: { file_path: join(h.root, "flake.nix") } };
    assert.match(h.hook("PostToolUse", read).stdout, /bounded memory/);
    h.hook("SessionStart", { source: "resume" });
    assert.equal(h.hook("PostToolUse", read).stdout, "");
    h.hook("SessionStart", { source: "compact" });
    assert.match(h.hook("PostToolUse", read).stdout, /bounded memory/);
    h.hook("SessionStart", { source: "clear" });
    assert.match(h.hook("PostToolUse", read).stdout, /bounded memory/);
});

scenario("a broken event shows no rules and never blocks", (h) => {
    const output = h.hook("PostToolUse", { tool_name: "Bash", tool_input: {} }, /agent-rules: missing shell command/);
    assert.equal(output.stdout, "");
});

function harness() {
    const root = mkdtempSync("/var/tmp/agent-rules-test-");
    // Fixture rules, so the scenarios do not depend on what is installed.
    mkdirSync(join(root, "rules"));
    writeFileSync(
        join(root, "rules/rust.md"),
        '---\nwhen: "*.rs"\n---\n\n# Rust\n\n- `pub(crate)` shares code; it does not expose a boundary.\n',
    );
    // Wrapped the way prettier wraps a value longer than its print width.
    writeFileSync(
        join(root, "rules/code.md"),
        '---\nwhen:\n    "*.c *.h\n    *.zig"\n---\n\n# Code\n\n- Globs continue on indented lines.\n',
    );
    writeFileSync(
        join(root, "rules/nix.md"),
        '---\nwhen: "*.nix"\ncommands: "nix nixos-rebuild"\n---\n\n# Nix\n\n- Evaluate with bounded memory.\n',
    );

    // Rules never block, so every call exits 0; stderr shows what went wrong,
    // and only the scenario that expects an error may see one.
    function hook(event: string, fields: Record<string, unknown> = {}, error?: RegExp) {
        const result = spawnSync(process.execPath, ["--experimental-strip-types", rules, "test"], {
            input: JSON.stringify({ session_id: "session", cwd: root, hook_event_name: event, ...fields }),
            cwd: root,
            encoding: "utf8",
            timeout: 15_000,
            env: { ...process.env, XDG_STATE_HOME: join(root, "state"), AGENT_RULES_DIR: join(root, "rules") },
        });
        assert.equal(result.status, 0, `${event}: ${result.error ?? ""}\n${result.stderr}`);

        if (error) {
            assert.match(result.stderr, error);
        } else {
            assert.equal(result.stderr, "", event);
        }

        if (result.stdout) JSON.parse(result.stdout);
        return result;
    }

    return { root, hook };
}
