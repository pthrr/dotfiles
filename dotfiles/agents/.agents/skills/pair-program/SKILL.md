---
name: pair-program
description: "Pair-program with the user on a Rust or TypeScript project. The user edits in Neovim between turns and owns the design: which public types and functions exist and how they are split into flat files under src/. The agent proposes structure, fills in bodies, has tests written from contracts the user approved, and debugs failures, one approved request at a time. Use it whenever the user wants to build or work on such a project together, for example 'create a ts app that does x and y', 'write a rust cli for …', 'lets start a new project', 'lets work on this project' or 'continue where we left off', and when the user asks to add, split, fill, test, fix or debug code in a project with this layout (flat src/, tests/integration/, tests/system/, flake.nix, Taskfile.yml). For an existing project with a different layout, use it only when the user asks for it."
---

# Pair-program on primitives

The user and you shape a codebase together. The user has two windows, this chat and Neovim, and goes back and forth:
they edit code themselves, then ask you to add or split primitives, fill or fix them, and above all to write tests and
debug failures. Two decisions carry the design and keep changing: which primitives exist, and how they are grouped into
files. Everything else is fixed, below and in `references/setup.md`, so it never has to be discussed.

The code is the only state. Every fact (primitives, signatures, grouping, dependencies, stubs, contracts) lives in
exactly one place in the code. Never copy it into a second file; derive overviews on demand (see Map).

## Roles

- Design is the user's: files, primitives, signatures and contract statements. Propose them; never change them unasked.
- Implementation is yours within a request: bodies, private helpers and test code.

## Definitions

- **Primitive**: a top-level public item. Rust: a bare `pub` struct, enum, trait, type, fn, const or static outside
  `lib.rs` and `main.rs`; `pub(crate)` counts as private. TypeScript: a top-level `export` outside `main.ts`. Public
  methods belong to their type. Anything non-public is a private helper; add those inside a file as a body needs them.
- **Stub**: a primitive whose body marks its parameters used and fails. The project still builds and lints clean
  (Clippy and `tsc` with `noUnusedParameters` reject unused parameters):

  ```rust
  pub fn render_all(entries: &[Entry]) -> String {
      let _ = entries;
      todo!()
  }
  ```

  ```ts
  export function renderAll(entries: Entry[]): string {
    void entries;
    throw new Error("todo");
  }
  ```

  Several parameters: `let _ = (first, second);`, and one `void` line each in TypeScript.
- **Contract**: a property of one or more primitives, from any files, checked through the public API by exactly one
  test file in `tests/integration/`. Its doc comment states the property in a few bullets. A bullet that says "for
  every …" is tested with generated inputs, from a generator that follows the bullet's conditions; other bullets are
  tested with examples. It covers the primitives it imports, plus the types in their signatures.
- **Scenario**: one end-to-end behaviour, checked by one test file in `tests/system/` through the program's entry point
  only.

## Layout

```
README.md                         the problem statement, a few lines; the only fact not in code
flake.nix  Taskfile.yml  .gitignore
Cargo.toml                        package.json  tsconfig.json  pnpm-lock.yaml (generated)
src/<file>.rs                     src/<file>.ts
tests/integration/<contract>.rs   tests/integration/<contract>.test.ts
tests/system/<scenario>.rs        tests/system/<scenario>.test.ts
```

Flat files only, snake_case names; `lib` and `main` are reserved. In `tests/<suite>/`, `support` is reserved for
generators shared by several contracts: a generator lives in its contract's test file until a second contract needs it,
then it moves to `support`, so no generator exists twice. Every src and test file starts with a doc comment
(Rust `//!`, TypeScript a leading `/** */`): a src file names the design decision it hides (see Split heuristics) in one
line, a test file states its contract or scenario in a few bullets. No unit tests inside `src/`: private helpers are
tested through the contracts of the primitives that use them.

### Rust

- `src/lib.rs` holds only `pub mod <file>;` lines. `src/main.rs`, if the project is a program, holds only the entry
  point.
- `tests/integration/main.rs` and `tests/system/main.rs` hold only `mod <test file>;` lines. Cargo builds each as one
  test target, `integration` and `system`.
- Tests import by full path: `use <crate>::<file>::<primitive>;`.
- Scenarios spawn the binary: `Command::new(env!("CARGO_BIN_EXE_<name>"))`.
- Property tests use `proptest` (dev-dependency). Every `proptest!` block turns failure persistence off
  (`failure_persistence: None`, see `references/setup.md`), so no `proptest-regressions/` folder appears.

### TypeScript

TypeScript follows `~/.agents/rules/typescript.md`.

- Tests import `../../src/<file>.ts` directly.
- Property tests run `fast-check` inside a `test`: `fc.assert(fc.property(keys, values, (key, value) => { … }))`.
- `src/main.ts`, if the project is a program, exports only `main`. It takes everything it reads and writes as
  parameters, so a scenario calls it like the process would, and it runs itself only when started directly (see
  `references/setup.md`).

## Toolchain

Your shell does not start inside the dev shell: run every build, lint and test as `nix develop -c task <name>`.

Every Taskfile has a `default` task that lists all tasks, and a `test` task that watches `src/`, `tests/` and the
project files and reruns `pre` on every change. The user keeps `nix develop -c task test` running in a terminal next
to Neovim. Each run (the `test:once` task) touches `.task/test.started` when it begins and replaces `.task/test.log`
when it ends, so the log always holds the last complete run, ending in `PASS` or `FAIL` (see Test results).

Neovim formats code on save: `rustfmt` for Rust, prettier for TypeScript. Nothing else formats code or checks its
formatting; `cargo fmt` is never used.

The flakes, Taskfiles and `.gitignore` are in `references/setup.md`.

## Map

Derive the overview from the code. Every command below is read-only.

Rust:

```sh
rg -n '^//!' src tests                          # decisions, contracts, scenarios
rg -n '^pub ' src -g '!lib.rs' -g '!main.rs'    # primitives
rg -n 'todo!\(\)' src                           # stubs
rg -U -n '^use crate::[^;]*;' src               # file uses
rg -U -n '^use [^;]*;' tests -g '!main.rs'      # what each test imports
```

TypeScript:

```sh
rg -U -n '^/\*\*(?s:.)*?\*/' src tests          # decisions, contracts, scenarios
rg -n '^export ' src -g '!main.ts'              # primitives
rg -n 'throw new Error\("todo"\)' src           # stubs
rg -n 'from "\./' src                           # file uses
rg -U -n '^import [^;]*;' tests                 # what each test imports
```

A stub line belongs to the nearest primitive above it in the same file. Show per src file its decision, its primitives
with stubs marked, and the files it uses; per test file its bullets and the primitives it covers. Then flag:

- a cycle in the file uses;
- a primitive no contract covers;
- a test that covers a stub, which fails until the stub is filled.

## Session

1. At the first request of a session, read `README.md`, run Map, and write the session plan to `PLAN.md` in the
   project root:

   ```markdown
   # Pair-program on <project>

   ## Problem

   <The problem statement from README.md, one or two lines.> The user asks for one change at a time in the chat; each
   reply states the exact change, and the change is made after the user's `ok`.

   ## Changes

   - `src/` — primitives, stubs, bodies and private helpers, as each request states
   - `tests/` — contract and scenario test files and the test roots, as each request states
   - `README.md` — the problem statement, only when the user restates the problem
   - `Cargo.toml` — package metadata and the dependencies a request names
   - `Taskfile.yml` — tasks, only when a request needs a new one
   - `flake.nix` — dev shell tools, only when a request needs a new one
   - `.gitignore` — ignored build output, only when a new kind appears

   ## Verify

   `pre` passes after every request, read from the watcher's `.task/test.log` (or from
   `nix develop -c task test:once` when the watcher is not running), or the reply names the tests that fail and why.
   ```

   TypeScript projects list `package.json` (the dependencies a request names) and `tsconfig.json` (compiler settings a
   request needs) instead of `Cargo.toml`.
2. Answer every request with the exact change (files, primitives with signatures, contract bullets) and stop; make it
   after the user's `ok`, under the unchanged session plan.
3. Begin every turn by picking up the user's Neovim edits: `git status --short`, then `git diff` on the files involved,
   then re-read them. If one breaks the build, say so. You see only the files on disk, and Neovim does not reload a
   buffer with unsaved edits when you change its file, so the user saves all buffers (`:wa`) before sending a request.
   If `git diff` misses a change the user mentions, ask before editing.
4. End every turn with the changed `file:line`s, the `pre` result (see Test results), and at most a few design signals
   from Map and the heuristics below, as suggestions only.

### Test results

Read the watcher's log instead of running the tests. Both checks are read-only:

```sh
find src tests Cargo.toml -newer .task/test.started -type f   # nothing: the last run started after every change
test .task/test.log -nt .task/test.started && echo complete   # and that run has finished
```

TypeScript checks `package.json tsconfig.json` instead of `Cargo.toml`, the files the watcher watches.

When both hold, `.task/test.log` describes the code on disk: its last line is `PASS` or `FAIL`, and the lines before
it hold the failures. After a change you made under an approved plan, wait for the watcher's next complete run
instead of running `pre` yourself, which would also compete with the watcher for Cargo's build lock:

```sh
timeout 120 sh -c 'until test .task/test.log -nt .task/test.started &&
  test -z "$(find src tests Cargo.toml -newer .task/test.started -type f)"; do sleep 1; done'
```

If it times out or `.task/test.log` does not exist, the watcher is not running: run `nix develop -c task test:once`,
which updates the log the same way, and ask the user to start `nix develop -c task test`.

## Requests

**Start**, once per project. Agree in chat on the problem statement, the files with the decision each hides, and the
primitives with their signatures; propose a walking skeleton (the fewest primitives that run one scenario end to end)
with one contract and one scenario. Then write PLAN.md as in Session, but with `Start <project>` as its title and the
files to create as its Changes. After the user's `ok`, set the project up as `references/setup.md` says.

**Shape**: add, split, merge, move or rename primitives or files, without changing behaviour. Read the test results
first (see Test results); afterwards the same tests pass and the same tests fail. Never combine a Shape with a Fill or
a Fix in one request: structure and behaviour change in separate steps (Beck's two hats). Added primitives are stubs.
Callers, imports, the `mod` lines in the roots, and the tests follow the move. If the result breaks a heuristic, say so
once and do it the user's way.

**Fill**: write the bodies of the named stubs. Refuse a primitive that needs another stub to work, and name that stub.
If no contract covers a stub yet, propose the Test request first (test first, as in Beck's test-driven development);
its tests fail until the Fill.

**Test**: propose the contract bullets (or scenario bullets) in the reply. After `ok`, start one fresh sub-agent
(Claude Code: the `Agent` tool, general-purpose) with the brief below, filled in from Map and the bullets, and report
its result. The sub-agent never sees a body, so its tests cannot repeat the code's mistakes; a test written from the
same reading as the code fails together with it (Knight & Leveson). Failures go to Fix and debug. In other clients,
write the tests yourself under the same limits: from the brief's content only, without reading `src/`.

```text
You write one test file for the project at <root>, from the contract and the API below only. Do not read anything
under src/, so your tests cannot repeat a mistake in the code.

- First read ~/.claude/CLAUDE.md and every file in ~/.agents/rules/ whose `when:` globs match the test file, and
  follow them.
- File: <tests/<suite>/<name>.rs or .test.ts>. Rust: also add `mod <name>;` to tests/<suite>/main.rs.
- Doc comment, verbatim: <the bullets>
- API, signatures and public type definitions without bodies: <from Map>
- Imports: <use paths, or ../../src/<file>.ts>. Generators in tests/<suite>/support: <names, or none>.
- A bullet that says "for every …" gets a property test whose generator follows the bullet's conditions (Rust:
  proptest with failure_persistence: None; TypeScript: fast-check). Every other bullet gets example tests.
- Run `nix develop -c task test:<suite>` in <root>. Never change a test to make it pass, and never read src/ to
  explain a failure.
- Report the files you wrote, every file you read, and for each failing test its bullet and its failure output.
```

**Fix and debug**: the contract decides who is wrong.

- The test deviates from the contract: fix the test.
- The primitive violates the contract: fix the primitive.
- The contract or a signature looks wrong: stop and ask; that is design.

A failing property's shrunk counterexample first becomes an explicit example test in the contract's file, which keeps
it without regression files; then the contract decides who is wrong. Diagnose from the watcher's `.task/test.log`
(see Test results) and propose the fix, all before any `ok`. Only when the watcher is not running, ask the user to
type `! nix develop -c task test:once`, or ask for `ok` to run the tests, diagnose and fix.

## Split heuristics

Use them to propose structure and to name design signals. They inform the user's decision; they never override it.

Primitive split:

- Types first; functions are transforms between existing types (data-oriented design).
- Push invariants into types where cheap (newtypes, enums, TypeScript unions), so fewer contracts are needed.
- A primitive no contract covers has no reason to be public: make it private or merge it into another.
- A contract joining unrelated outcomes splits into two.
- A contract that is hard to state in a few bullets, or hard to test through the public API, signals a bad primitive
  or file split ("listen to the tests", Freeman & Pryce).

File split:

- A file hides one design decision that is likely to change: a data format, an algorithm, a side-effect boundary (fs,
  net, clock, process). Its doc comment names that decision (Parnas). Side effects get files of their own, so
  everything else is testable without I/O.
- Primitives in one file use each other or share a type; otherwise split the file (Divergent Change).
- A primitive that uses another file's types more than its own file's moves there (Feature Envy).
- File uses stay acyclic. A cycle means moving a primitive or extracting the shared type into its own file.
- Files imported together by many contracts, or that keep changing together, are merge candidates (Shotgun Surgery).
- A file too long to read and reason about in one go is a split candidate.
