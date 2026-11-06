# Agents

Global instructions for every repository. A repository's own AGENTS.md is loaded after this file and wins where the two
conflict.

## Etiquette

- Be precise in what you propose and explain (what/why/where/current/future)
- When I ask for an explanation, keep in mind that I most often will not have the concrete code and problem at the top
  of my head. Provide context and explain from first principles.
- Never start writing code right away. Plan first and implement only when I agreed.

## Approval gate

Hooks in `~/.agents/hooks` enforce "plan first, implement only when agreed" for every client. Work with them from your
first tool call:

- Always allowed: reading files, read-only shell commands, writing any `PLAN.md`, and writing under `~/.claude`,
  `~/.codex`, `~/.agents`, `~/.config/opencode`, `~/.local/share/opencode`, `~/tmp` and `/tmp`.
- A shell command is read-only only if every command in it is on the allowlist in `~/.agents/hooks/shell-policy.ts`, for
  example `ls`, `cat`, `head`, `tail`, `grep`, `rg`, `find` without `-exec`/`-delete`, `sed -n 'N,Mp'`, `jq`, `diff`,
  `wc`, `which` and `git status|diff|log|show|ls-files|ls-tree|rev-parse`. `$`, backticks, `\` outside quotes, `<`, `(`
  and any redirection other than to `/dev/null` or `2>&1` make the whole command gated.
- Everything else needs an approved plan: creating or editing any other file, and every other shell command (builds,
  tests, formatters, `nvim`, `git commit`), even one that only reads.
- To get approval, write `PLAN.md` at the root of the repository you will change (a file is governed by the nearest
  `PLAN.md` at or above it inside its repository), end your turn with the complete `PLAN.md` text in your final message
  (verbatim; only whitespace may differ), and wait. Only a reply of exactly `ok` approves; "yes", "go" or "fix #2" do
  not, and an `ok` sent before the plan was shown approves nothing.
- Approval covers edits to the files listed under `## Changes` and any shell command, until the next human message that
  is not exactly `ok`. A later `ok` resumes the same plan if it is unchanged.
- Changing `PLAN.md` withdraws approval: show the new version in full and wait for a new `ok`. To touch a file the plan
  does not list, add it to the plan first. Deleting `PLAN.md` closes the plan.
- A turn that wrote `PLAN.md` cannot end until its final message shows it in full. Show one plan per message.
- `PLAN.md` format, checked by `~/.agents/hooks/write-gate.sh`:

      # <title>
      ## Problem
      <what is wrong or wanted, and why>
      ## Changes
      - `path/to/file` — <what changes, current -> future, why; at least five words>
      - `path/to/dir/` — <the same, for everything under the directory>
      ## Verify
      <commands or checks that prove it works>

    Paths are relative to the directory holding `PLAN.md`, or absolute, and must lie below it; `./` is rejected.

- A rejection names what is missing. Do not retry the same call or route around the gate; fix the plan or ask for `ok`.
- After each write, rules from `~/.agents/rules/*.md` whose `when:` globs match the written path are added to your
  context. Follow them. Before writing code, read `~/.agents/rules/code.md` and the rules file of its language: the
  hook adds them only after the first matching write.

## Think before coding

- State your assumptions explicitly. If something is unclear, stop, name what is confusing, and ask.
- If the goal is unclear, ask before planning. If only the design is open, decide: give one recommendation and why, not
  a list of options.
- If a simpler approach exists, say so. Push back when warranted.

## Simplicity first

- Make sure changes are minimal and reuse as much existent primitives as possible (YAGNI)
- No features beyond what was asked, no abstractions for single-use code, no configurability that was not requested, no
  error handling for impossible cases.

## Surgical changes

- Touch only what the task needs. Do not "improve" adjacent code, comments or formatting, and do not refactor what is
  not broken.
- Match existing style, even if you would do it differently.
- If you notice unrelated dead code or problems, mention them; do not fix them unasked.
- Remove imports, variables and functions that your changes made unused, and nothing else.
- Every changed line should trace directly to the request.

## Goal-driven execution

- Turn the task into verifiable goals: "fix the bug" becomes "write a test that reproduces it, then make it pass".
- For multi-step tasks, state a brief plan with a check for each step, and loop until every check passes.
