---
name: parallelize-work
description: Split an approved task into independent units and run one sub-agent per unit at the same time, each in its own git worktree and branch, each running its builds and tests locally or through offload-compute as it sees fit, then combine their changes in the main checkout. Use when a task divides into units that touch disjoint files and each unit needs its own reading, editing or analysis. Not for one sequential change or a pure compute fan-out.
---

# Parallelize work across worktrees

The lead (you) splits a task into units, gets them approved once through
PLAN.md, and starts one sub-agent, a worker, per unit. Each worker edits only
its own git worktree, runs its builds and tests where it sees fit, locally or
through offload-compute (`~/.agents/skills/offload-compute/SKILL.md`), and
commits on its own branch.
The lead then applies the branches to the main checkout as uncommitted
changes, so the result looks like one agent's edits and the user commits.

Claude Code only. Its sub-agents run in the lead's session, so the user's one
`ok` covers them. OpenCode sub-agents are sessions of their own without an
`ok`; Codex is unverified. Elsewhere, do the units one after another.

## When not to use it

- Units depend on each other's results, or two units must change the same
  file. Do them in sequence, or merge the overlapping units into one.
- The parallel part is pure computation: a parameter sweep, test shards, a
  fuzzing campaign. Write one TinyCI job file with one job per shard; the
  server runs them without spending agent tokens.
- The task is small. Every worker starts from a fresh context and rereads
  what the lead already knows.

## Throughput

Workers multiply agent work (reading, editing, analysing results). The
commands they run share whatever runs them: locally, this machine's cores and
memory, with a cold build in every worktree; offloaded, TinyCI's four job
slots, each at most 2 CPU and 8 GiB, with the rest queued. Workers also edit
while other workers' commands run. Start at most four workers unless the user
asks for more; every tool call of every worker, reads included, also waits its
turn on the session's one hook lock.

## 1. Plan

Read enough to split the task, then write PLAN.md in the main checkout's root
with the usual sections, plus:

- `## Workers`: one line per unit with its name, the files it changes, and
  the check that proves it done. The name (`[A-Za-z0-9][A-Za-z0-9_.-]*`) also
  names its branch `par/<unit>`, worktree `.worktrees/<unit>`, and its run
  label if it offloads.
- `## Changes`: every file any unit changes, relative to the main checkout,
  and `.offload-jobs.json`, so any worker may offload. A write inside a
  worktree is judged as the same
  path in the main checkout, so a file missing here is denied in every
  worktree.

Units must have disjoint files. The main checkout must have no uncommitted
changes in them: worktrees start from `HEAD`, and their diffs are applied on
top. Show the plan and wait for `ok`.

The `ok` covers every step below, and it is the user's request to start the
sub-agents; ask nothing else until the workers have reported. Any other
message from the user while workers run pauses all of them until a new `ok`.

## 2. Prepare

Use absolute paths throughout, and `git -C` instead of `cd`. Keep the
worktrees and job files out of `git status` (once per repository), then add
one worktree per unit:

```sh
repo=$(git rev-parse --show-toplevel)
exclude=$(git -C "$repo" rev-parse --path-format=absolute --git-path info/exclude)
grep -qxF /.worktrees/ "$exclude" || echo /.worktrees/ >>"$exclude"
grep -qxF /.offload-jobs.json "$exclude" || echo /.offload-jobs.json >>"$exclude"
git -C "$repo" worktree add -b par/<unit> "$repo/.worktrees/<unit>" HEAD
```

When units need the same dependencies or toolchain, prepare them once before
starting the workers: locally, in a place every worktree reaches by absolute
path, or as one offload-compute setup job whose `output_tree` each offloading
worker takes as a `tree:<digest>` input. Identical setup jobs submitted
together would all execute: a cached result exists only once one succeeded.

## 3. Start the workers

Start all workers in one message, one sub-agent each, so they run at the same
time. Give each this brief, filled in:

```text
You are worker <unit> of a parallel task. The user approved <repo>/PLAN.md;
read it, in particular the ## Workers line for <unit>.

- Work only in <repo>/.worktrees/<unit>, on branch par/<unit>, and change
  only these files: <files>. Use absolute paths, and `git -C <worktree>`
  instead of `cd`.
- Before editing, read ~/.claude/CLAUDE.md and every file in ~/.agents/rules/
  whose `when:` globs match your files, and follow them. The hooks show those
  rules only to the first agent of the session that writes a matching file.
- Decide where your builds and tests run. Run them locally when they are
  quick and light. Offload them through
  ~/.agents/skills/offload-compute/SKILL.md when they run for many minutes,
  need more CPU or memory than this machine should spend, or should keep
  running while it sleeps; the other workers share this machine, each with a
  cold build in its own worktree.
- If you offload: write the job file as <worktree>/.offload-jobs.json, submit
  with `--label par/<unit>`, and wait for the run with `wait` in the
  foreground, not `follow` in the background. Give `wait` the longest shell
  timeout; if the time limit cuts it off, run it again, since it only polls
  the server. If the repo builds and tests through `task`, the job runs the
  same `task` commands when the image provides `task`.
  <Shared setup, if any: locally at <path>, or tree:<digest> as an input for
  ...>
- You are done when: <check>.
- If the write gate denies an edit, stop and report it. Never make that edit
  through the shell instead.
- Commit only your files on par/<unit>: `git -C <worktree> add <files>`,
  then `git -C <worktree> commit`.
- Report your branch, commit, where your checks ran (with TinyCI run IDs and
  labels if you offloaded), whether the check passed, and anything left
  undone.
```

If workers offloaded, give the user the dashboard URL once, then each
worker's run ID and label as it reports.

## 4. Combine

Once every worker has reported:

1. Apply the branch of each unit whose check passed to the main checkout, as
   uncommitted changes:

   ```sh
   git -C "$repo" diff --binary HEAD...par/<unit> | git -C "$repo" apply
   ```

   `git apply` changes nothing if any hunk fails. Disjoint files apply
   cleanly, so a failure means a unit changed a file outside its list:
   resolve it within the plan's `## Changes`, or report it.
2. Run the combined check from the main checkout, locally or through
   offload-compute by the same criteria as the workers.
3. Remove each applied unit's worktree and branch. `-D`, because the branch
   was applied, not merged:

   ```sh
   git -C "$repo" worktree remove "$repo/.worktrees/<unit>"
   git -C "$repo" branch -D par/<unit>
   ```

   Keep a failed unit's worktree and branch until the user decides.
4. Report per unit: the result, where its checks ran and any run IDs, and
   what is left. The changes are uncommitted; the user commits them.
