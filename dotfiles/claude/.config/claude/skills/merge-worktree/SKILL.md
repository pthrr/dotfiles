---
name: merge-worktree
description: Merge claude worktree branches back into the main branch using rebase for linear history. Use after finishing work in `claude -w` sessions. Supports single branch or batch merging all worktree branches.
disable-model-invocation: true
argument-hint: "[<worktree-name> | --all]"
allowed-tools:
  - Bash
---

Merge worktree branches back into the main branch with a linear history.

## Modes

- `/merge-worktree feature-x` — merge a single worktree branch
- `/merge-worktree --all` — batch merge all `worktree-*` branches, one by one
- `/merge-worktree` (no args) — list all `worktree-*` branches and ask what to do

## Steps

1. Determine the main branch: check for `main`, then `master`
2. List worktree branches to merge:
   - Single: `worktree-<arg>`
   - Batch (`--all`): all branches matching `worktree-*`
   - No args: list branches matching `worktree-*` and ask which one(s)
3. For each branch, in sequence:
   a. Show commits: `git log --oneline <main>..<worktree-branch>`
   b. Ask the user to confirm, skip, or abort the whole batch
   c. Rebase onto main: `git rebase <main> <worktree-branch>`
   d. If conflicts arise, stop and help resolve them before continuing
   e. Fast-forward merge: `git checkout <main> && git merge --ff-only <worktree-branch>`
   f. Clean up: `git branch -d <worktree-branch>`
   g. Remove worktree dir if it exists: `git worktree remove .claude/worktrees/<name>`
   h. Main is now updated, so the next branch rebases on top of the previous one
4. Show final `git log --oneline -10` to confirm

## Important

- Never force-push or reset without explicit user confirmation
- If rebase has conflicts, pause and help resolve them before moving to the next branch
- Always show the commit list and ask for confirmation before each merge
- On user abort, stop immediately and leave remaining branches untouched
