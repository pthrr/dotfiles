# dotfiles

## Setup and recovery

This checkout configures a Fedora machine with DNF, single-user Nix, and Home
Manager. The top-level `./install.sh` updates system packages, changes system
settings, installs Nix and Home Manager, then activates the home configuration.
After cloning, run `git submodule update --init --recursive` so the `nixbits`
helpers used by Home Manager are present.
Read the scripts in `system/` before running it on another machine. In
particular, `install.sh` removes the existing `~/.bashrc` and `~/.profile`;
back up any personal contents first.

For an existing Nix and Home Manager installation, install the Nix configuration
and apply home changes from this checkout:

```sh
./dotfiles/install.sh nix/
home-manager switch
```

After editing files managed by Home Manager, run `home-manager switch` again.
For development, enter the pinned tool environment with `nix develop` and run
`task ci` to check this repository and `nixbits`. Run `pre-commit install` once
to enable fast syntax and `nixbits` checks before commits. You can run only the
helper checks with `task nixbits:ci`.
Restart agent clients after changing their hooks so they load the new definitions.
If a switch fails, correct or revert the source change and run it again. If an
initial install stopped after removing shell files, restore `~/.bashrc` and
`~/.profile` from the backups you made before installation. Home Manager does
not undo the system-level DNF and systemd changes in `install.sh`.

The SSD backup script is specific to the UUIDs in `system/sync_ssd.bash`. Mount
those target partitions, check their UUIDs against the script, then run
`sudo ./system/sync_ssd.bash`. It asks before unmounting `~/Drive`, previews
rsync changes (including deletions), and asks again before writing. Inspect the
preview before confirming. If restoring files, mount the backup and copy the
needed files back explicitly; the sync script only copies toward the backup.

## Shared agent configuration

Agent configuration has one source of truth in `dotfiles/agents/.agents/`:

```text
.agents/
├── skills/         # Shared SKILL.md packages
├── hooks/          # Shared checks, TypeScript event adapter, and tests
├── claude/         # Claude hook plugin, settings seed, and status line
├── codex/          # Codex hook event configuration
└── opencode/       # OpenCode settings template and TypeScript hook bridge
```

Home Manager installs this tree into `~/.agents`. The
[`home.nix`](dotfiles/nix/.config/home-manager/home.nix) configuration also provides
the entry points clients need, all backed by the same source files:

| Harness | Configuration entry point | Shared skills |
| --- | --- | --- |
| Codex | `~/.codex/hooks.json` links to `.agents/codex/hooks.json` | `~/.codex/skills` mirrors `.agents/skills` |
| Claude Code | `~/.claude/skills/agent-hooks` links to `.agents/claude/plugin` | `~/.claude/skills` mirrors `.agents/skills` |
| OpenCode | `~/.config/opencode/opencode.json` is generated from `.agents/opencode/opencode.json.in` and names the plugin | Discovers `~/.agents/skills` |

Discovery paths follow the official documentation for
[Codex skills](https://learn.chatgpt.com/docs/build-skills),
[Claude skills](https://code.claude.com/docs/en/skills),
[OpenCode skills](https://opencode.ai/docs/skills/).

OpenCode reads `~/.agents/skills` on its own. Codex does not: it loads skills
only from `$CODEX_HOME/skills`, which is why that mirror exists.

OpenCode's settings are maintained in
`.agents/opencode/opencode.json.in`: its `plugin` entry is a module specifier
with no `~` expansion, so Home Manager writes the absolute path in.

No other harness gets a model from this repo — each one remembers what you pick.
Codex writes its choice to `~/.codex/config.toml`, OpenCode keeps the last
selection in its own database, and Claude Code saves `/model` and `/effort` into
`~/.claude/settings.json`.

That file is deliberately not a Nix store symlink: Claude Code writes to it, and
against a read-only link those saves fail without reporting it. Home Manager only
seeds it, once, from `.agents/claude/settings.seed.json` when no file is there —
the settings with no plugin equivalent, `statusLine` among them. Everything after
that belongs to Claude Code. Change the seed and an existing file will not be
touched; edit `~/.claude/settings.json` directly, or delete it and re-run
`home-manager switch`.

The hooks reach Claude through `~/.claude/skills/agent-hooks` instead. Any
directory under `~/.claude/skills` holding a `.claude-plugin/plugin.json` loads
as `<name>@skills-dir` with no marketplace and no `enabledPlugins` entry, and
`hooks/hooks.json` inside it is a hook source in its own right. `claude plugin
details agent-hooks@skills-dir` lists what it registers; a hooks-only plugin adds
no model context. Claude's plugin and Codex's `~/.codex/hooks.json` invoke the
same TypeScript adapter in `~/.agents/hooks/adapter.ts`. OpenCode's local
[TypeScript plugin](https://opencode.ai/docs/plugins/) translates its prompt and
tool events for that adapter. The existing shell
validators implement consent, `PLAN.md` checks, and design-loop output checks
once for all three harnesses. Node runs the TypeScript directly; no npm install or
build step is needed. Home Manager supplies Node and `flock`.

`UserPromptSubmit` records the latest prompt. File edits and shell commands
outside a conservative read-only allowlist require `yes`, `y`, or `ok` in that
prompt. Every patch target, including both rename endpoints, needs an applicable
plan. An edit to `PLAN.md` itself only needs consent. Shell commands need a plan
in their working directory and any directly identifiable `cd` destinations.
The hook does not execute the shell command to classify it.

The design loop activates when the current prompt names `software-design` or
the design loop and the skill is successfully invoked with Claude's `Skill`
tool or OpenCode's `skill` tool, or when the prompt explicitly selects
`$software-design` in Codex. Reading the skill file alone does not activate it.
Once active, `Stop` validates the final response for turns that attempted
approved writes.
Resume and compaction restore the design instructions. A resumed session needs
fresh consent; compaction preserves consent within the current turn.

OpenCode has no blocking `Stop` hook. On `session.idle`, its bridge applies the
same final-response check and requests at most one correction with the session's
selected model. This happens after the initial response is visible. Generated
feedback cannot grant consent.

Session state lives under `${XDG_STATE_HOME:-~/.local/state}/agent-hooks/`,
separated by client and session and locked against concurrent hook calls.
Fresh sessions and `/clear` reset the loop. Missing or corrupt state cannot grant
edit permission. Restart the client after installing these hooks so prompt
capture is active from the start of the session.

These are workflow guardrails. Arbitrary shell programs can write beyond their
working directory; MCP write tools and input sent to an already-running terminal
are not covered by the configured write matchers. Keep the clients' sandbox and
permission controls enabled. See the official
[Codex hook behavior and coverage](https://learn.chatgpt.com/docs/hooks) and
[Claude hook reference](https://code.claude.com/docs/en/hooks). OpenCode covers
`write`, `edit`, `multiedit`, `apply_patch`, `shell`/`bash`, and code execution;
custom tools and MCP writes have the same coverage limits.

Client histories, caches, and third-party plugins remain in their own
directories. Maintain the shared settings and hook code under `.agents`.

Edit the source files here, then run `home-manager switch` to apply them. This
replaces the former `dotfiles/claude` source package; Home Manager removes its
old managed `~/.claude/*.sh` links during activation. The standalone Stow `agents`
package installs the shared tree only; Home Manager supplies the client bridges.

After activation, open `/hooks` in Codex and review/trust the new hook definitions.
Codex skips untrusted hooks; changing a definition requires review again.

Check shell syntax and the Nix expression without applying system changes:

```sh
bash -n install.sh dotfiles/install.sh system/*.sh system/*.bash
nix-instantiate --parse dotfiles/nix/.config/home-manager/home.nix >/dev/null
```

Run the existing hook checks with:

```sh
bash dotfiles/agents/.agents/hooks/ask-first.test.sh
bash dotfiles/agents/.agents/hooks/design-loop.test.sh
node --experimental-strip-types --test dotfiles/agents/.agents/hooks/adapter.test.ts
node --experimental-strip-types --test dotfiles/agents/.agents/opencode/plugin.test.ts
```
