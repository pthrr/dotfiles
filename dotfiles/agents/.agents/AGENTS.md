# Agents

Global instructions for every repository. A repository's own instructions file (CLAUDE.md for Claude Code, AGENTS.md for
Codex and OpenCode) is loaded after this file and wins where it conflicts with this file or with a rule from
`~/.agents/rules`.

## Etiquette

- Be precise in what you propose and explain (what/why/where/current/future)
- When I ask for an explanation, keep in mind that I most often will not have the concrete code and problem at the top
  of my head. Provide context and explain from first principles.

## Approval gate

Never start writing code right away: plan first and implement only when I agreed. Hooks in `~/.agents/hooks/gate`
enforce this for every client. Work with them from your first tool call:

- Always allowed: reading files, read-only shell commands, writing any `PLAN.md`, and writing under `~/.claude`,
  `~/.codex`, `~/.agents`, `~/.config/opencode`, `~/.local/share/opencode`, `~/tmp` and `/tmp`.
- A shell command is read-only only if every command in it is on the allowlist in `~/.agents/hooks/shell-policy.ts`, for
  example `ls`, `cat`, `head`, `tail`, `grep`, `rg`, `find` without `-exec`/`-delete`, `sed -n 'N,Mp'`, `jq`, `diff`,
  `wc`, `which` and `git status|diff|log|show|ls-files|ls-tree|rev-parse`. `$`, backticks, `\` outside quotes, `<`, `(`
  and any redirection other than to `/dev/null` or `2>&1` make the whole command gated.
- Everything else needs an approved plan: creating or editing any other file, and every other shell command (builds,
  tests, formatters, `nvim`), even one that only reads.
- To get approval, write `PLAN.md` at the root of the repository you will change (a file is governed by the nearest
  `PLAN.md` at or above it inside its repository), end your turn with the complete `PLAN.md` text in your final message
  (verbatim; only whitespace may differ), and wait. Only a reply of exactly `ok` approves; "yes", "go" or "fix #2" do
  not, and an `ok` sent before the plan was shown approves nothing.
- Approval covers edits to the files listed under `## Changes` and any shell command, until the next human message that
  is not exactly `ok`. A later `ok` resumes the same plan if it is unchanged.
- A file inside a linked git worktree is judged at the same path in its main checkout, so one plan covers the
  repository's worktrees.
- Sub-agents that run in your session share your approval, as Claude Code's do. Sub-agents that run as sessions of
  their own, as OpenCode's do, need an approval of their own.
- Changing `PLAN.md` withdraws approval: show the new version in full and wait for a new `ok`. To touch a file the plan
  does not list, add it to the plan first. Deleting `PLAN.md` closes the plan.
- Once every check under `## Verify` that you run has passed, delete `PLAN.md`. A plan is a working artifact: it is
  never committed, and no repository ignores it, so `git status` shows a forgotten one.
- A turn that wrote `PLAN.md` cannot end until its final message shows it in full. Show one plan per message.
- `PLAN.md` format, checked by `~/.agents/hooks/gate/write-gate.sh`:

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

## Commits

- Never create commits: the user commits. Every change you make stays uncommitted in the working tree.
- The one exception is a temporary commit on a throwaway branch, such as a worker's branch in its own worktree, that is
  applied to the working tree as uncommitted changes and then deleted.

## Rules

`~/.agents/rules/*.md` hold the knowledge for a language or tool. Hooks in `~/.agents/hooks/rules` add a rule to your
context after you write or read a path its `when:` globs match (reading through `cat`, `head`, `tail` or `sed -n`
counts), and after a shell command that runs a program its `commands:` names. Follow them.

- Each agent is shown each rule once per session, and again after compaction.
- Before writing a kind of file you have not read or written yet, read the rules whose `when:` matches it: the hook
  adds them only after the first matching event.

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

## Homelab

- `~/.topology.json` describes the homelab: hosts, addresses, networks, services and their ports. Read it before you
  address any homelab host or service, and take addresses and ports only from it, never from memory or a guess.
- If the file is missing, say so and stop.
