# dotfiles

Agent configuration has one source of truth in `dotfiles/agents/.agents/`:

```text
.agents/
├── skills/         # Shared SKILL.md packages
├── hooks/          # Shared checks, TypeScript event adapter, and tests
├── claude/         # Claude hook plugin, settings seed, and status line
├── codex/          # Codex hook event configuration
├── opencode/       # OpenCode settings template and TypeScript hook bridge
└── aider/          # Aider settings template and model metadata
```

Home Manager installs this tree into `~/.agents`. The
[`home.nix`](dotfiles/nix/.config/home-manager/home.nix) configuration also provides
the entry points clients need, all backed by the same source files:

| Harness | Configuration entry point | Shared skills |
| --- | --- | --- |
| Codex | `~/.codex/hooks.json` links to `.agents/codex/hooks.json` | `~/.codex/skills` mirrors `.agents/skills` |
| Claude Code | `~/.claude/skills/agent-hooks` links to `.agents/claude/plugin` | `~/.claude/skills` mirrors `.agents/skills` |
| OpenCode | `~/.config/opencode/opencode.json` is generated from `.agents/opencode/opencode.json.in` and names the plugin | Discovers `~/.agents/skills` |
| Aider | `~/.aider.conf.yml` links to the generated `.agents/aider/config.yml` | `/read ~/.agents/skills/<name>/SKILL.md` |

Discovery paths follow the official documentation for
[Codex skills](https://learn.chatgpt.com/docs/build-skills),
[Claude skills](https://code.claude.com/docs/en/skills),
[OpenCode skills](https://opencode.ai/docs/skills/), and
[Aider conventions](https://aider.chat/docs/usage/conventions.html).

OpenCode reads `~/.agents/skills` on its own. Codex does not: it loads skills
only from `$CODEX_HOME/skills`, which is why that mirror exists.

Aider's settings are maintained in `.agents/aider/config.yml.in`. Home Manager
fills in the metadata path and installs the result under `.agents/aider`. The
endpoint stays in that template; the key does not. Everything Home Manager
writes lands in the world-readable Nix store, so the key reaches Aider through
`AIDER_OPENAI_API_KEY`, exported by `.bashrc` from `~/.config/aider/key.txt`
(0600, never in git or the store). Aider keeps a model in the template because
it has no way to remember one itself.

OpenCode's settings are maintained the same way, in
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

The design loop activates when the skill is successfully invoked with Claude's
`Skill` tool, read with `Read`/`read_file` or a direct `cat`/`head`/`tail`/`sed`
command, OpenCode's `skill` tool, or explicitly selected with `$software-design`
in Codex. Once active, `Stop` validates the final response for turns that attempted approved writes.
Resume and compaction restore the design instructions. A resumed session needs
fresh consent; compaction preserves consent within the current turn.

OpenCode has no blocking `Stop` hook. On `session.idle`, its bridge applies the
same final-response check and requests at most one correction with the session's
selected model. This happens after the initial response is visible. Generated
feedback cannot grant consent. Aider has no equivalent prompt/tool hook API;
it shares the configuration folder and skill files, but does not enforce these
checks. Loading a skill in Aider requires the `/read` command above.

Session state lives under `${XDG_STATE_HOME:-~/.local/state}/agent-hooks/`,
separated by client and session and locked against concurrent hook calls.
Fresh sessions and `/clear` reset the loop. Missing or corrupt state cannot grant
edit permission. Restart the client after installing these hooks so prompt
capture is active from the start of the session.

These are workflow guardrails. Arbitrary shell programs can write beyond their
working directory; MCP write tools and input sent to an already-running terminal
are not covered by the configured write matchers. Skill reads hidden inside
arbitrary programs are not detected. Keep the clients' sandbox and permission
controls enabled. See the official
[Codex hook behavior and coverage](https://learn.chatgpt.com/docs/hooks) and
[Claude hook reference](https://code.claude.com/docs/en/hooks). OpenCode covers
`write`, `edit`, `multiedit`, `apply_patch`, `shell`/`bash`, and code execution;
custom tools and MCP writes have the same coverage limits.

Client histories, caches, and third-party plugins remain in their own
directories. Maintain the shared settings and hook code under `.agents`.

Edit the source files here, then run `home-manager switch` to apply them. This
replaces the former `dotfiles/claude` source package; Home Manager removes its
old managed `~/.claude/*.sh` links during activation. The standalone Stow `agents`
package installs the shared tree only; Home Manager supplies the client bridges
and Aider configuration.

After activation, open `/hooks` in Codex and review/trust the new hook definitions.
Codex skips untrusted hooks; changing a definition requires review again.

Run the existing hook checks with:

```sh
bash dotfiles/agents/.agents/hooks/ask-first.test.sh
bash dotfiles/agents/.agents/hooks/design-loop.test.sh
node --experimental-strip-types --test dotfiles/agents/.agents/hooks/adapter.test.ts
node --experimental-strip-types --test dotfiles/agents/.agents/opencode/plugin.test.ts
```
