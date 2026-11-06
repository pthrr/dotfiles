---
when: "*/Taskfile.yml */Taskfile.yaml"
---

# Taskfile

- Every Taskfile has a `default` task that lists all tasks (`task --list-all`), and a `test` task that watches the
  sources and reruns the tests on every change.
- Every Taskfile has an `update` task that bumps all dependencies to their newest versions at once, in every layer
  (`nix flake update` and the dependency manager's update), never one alone and never past the cool-off: a tool that
  cannot respect it stays out of `update`. The only other way a pinned version moves is an update bot such as Renovate
  that opens as few changes as it can: all updates of every layer in one, and its lockfile maintenance in another.
- Neovim formats each file on save, so no task formats code. Format checks run only in `pre`, the pre-commit tier, and
  catch files that never went through Neovim; `lint` checks no formatting. They run last in `pre`, after lint and the
  tests, so an unformatted file does not hide their results.
- We use test suites of stepped complexity (pre/ci/nightly).
- Test suite runs in pre-commit (task pre) with max duration of 60 seconds with a warm cache.
- CI runs are limited to 60 minutes.
- Nightly runs are limited to 6 hours.
