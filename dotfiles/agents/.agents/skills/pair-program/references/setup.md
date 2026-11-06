# Project setup

Read this for Start, and before changing `flake.nix`, `Taskfile.yml`, `Cargo.toml`, `.cargo/config.toml`,
`package.json`, `tsconfig.json`, `biome.json`, `pnpm-workspace.yaml` or `.gitignore`.

## Start

1. `git init` if the folder is not a repository yet.
2. Write `README.md`, `flake.nix`, `Taskfile.yml`, `.gitignore`, `Cargo.toml` and `.cargo/config.toml` or
   `package.json`, `tsconfig.json`, `biome.json` and `pnpm-workspace.yaml`, the roots (`lib.rs`, `main.rs`, the two test
   `main.rs` for Rust), the stubs, and the walking skeleton's contract and scenario test files.
3. `git add flake.nix`; a flake in a git repository ignores untracked files.
4. Rust: `nix develop -c cargo add --dev proptest`. TypeScript: `nix develop -c pnpm add tsx`, then
   `nix develop -c pnpm add -D typescript @types/node@<major> fast-check @biomejs/biome` (see TypeScript).
5. `nix develop -c task pre`, then `git add flake.lock`, which the first `nix develop` created. Afterwards, rewrite
   PLAN.md as the session plan.

## Rust

`Cargo.toml` sets the newest stable edition, as `cargo new` writes it. Neovim reads the edition from `Cargo.toml`, so a
save and `cargo fmt --check` agree. `.cargo/config.toml` holds the cool-off of the Rust rules:

```toml
[registry]
global-min-publish-age = "7 days"
```

Every `proptest!` block turns failure persistence off, so no `proptest-regressions/` folder appears:

```rust
proptest! {
    #![proptest_config(ProptestConfig {
        failure_persistence: None,
        ..ProptestConfig::default()
    })]

    #[test]
    fn render_then_parse_gives_the_same_entry(
        key in "[a-z]([a-z ]*[a-z])?",
        value in "([a-z=]([a-z =]*[a-z=])?)?",
    ) {
        let entry = Entry { key, value };
        prop_assert_eq!(parse_entry(&render_entry(&entry)), Some(entry));
    }
}
```

## TypeScript

- `tsconfig.json` holds the compiler options of the TypeScript rules, plus `"include": ["src", "tests"]`.
- `package.json` holds `"type": "module"` and the `devEngines` entry of the TypeScript rules.
- `biome.json` holds the formatter and linter settings of the TypeScript rules.
- `pnpm-workspace.yaml` holds the cool-off and the build-script rulings of the TypeScript rules, to start with
  `minimumReleaseAge: 10080` and `allowBuilds: { esbuild: false }` for tsx's esbuild.
- The starting dependency is `tsx`; the starting devDependencies are `typescript`, `@types/node@<major>` (as the
  TypeScript rules say), `fast-check` and `@biomejs/biome`.
- `src/main.ts` runs itself only when started directly:

  ```ts
  export function main(args: string[], write: (line: string) => void): number {
      // ...
  }

  if (import.meta.main) {
      process.exitCode = main(process.argv.slice(2), console.log);
  }
  ```

## Toolchain

Rust `flake.nix`:

```nix
{
  description = "<project>";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      rust-overlay,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "clippy"
            "rustfmt"
            "rust-src"
            "rust-analyzer"
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            rustToolchain
            pkgs.go-task
            pkgs.watchexec
            pkgs.util-linux
          ];
        };
      }
    );
}
```

TypeScript `flake.nix`: the same without `rust-overlay` (no input, `pkgs = import nixpkgs { inherit system; };`) and
with `packages = [ pkgs.nodejs-slim_<major> pkgs.pnpm pkgs.go-task pkgs.watchexec pkgs.util-linux ];` (`<major>` as the
TypeScript rules say; `nodejs-slim` is Node without npm and npx; `util-linux` brings `flock`).

Rust `Taskfile.yml`:

```yaml
version: "3"

set: [pipefail]

tasks:
  default:
    desc: List all tasks
    silent: true
    cmds:
      - task --list-all

  lint:
    desc: Check lints
    cmds:
      - cargo clippy --all-targets -- -D warnings

  format:check:
    desc: Check the formatting; Neovim formats each file on save
    cmds:
      - cargo fmt --check

  test:integration:
    desc: Run the contract tests
    cmds:
      - cargo test --test integration

  test:system:
    desc: Run the end-to-end scenarios
    cmds:
      - cargo test --test system

  pre:
    desc: Lint, run both test suites and check the formatting (pre-commit)
    cmds:
      - task: lint
      - task: test:integration
      - task: test:system
      - task: format:check

  test:
    desc: Rerun pre on every change; the last complete run is in .task/test.log
    preconditions:
      - sh: mkdir -p .task && flock --nonblock .task/test.lock true
        msg: Another task test already watches this folder
    cmds:
      - >-
        flock --nonblock .task/test.lock
        watchexec --restart --watch src --watch tests --watch Cargo.toml -- task test:once

  test:once:
    desc: Run pre once and keep its result in .task/test.log
    cmds:
      - mkdir -p .task
      - touch .task/test.started
      - task pre 2>&1 | tee .task/test.log.part && echo PASS >> .task/test.log.part || echo FAIL >> .task/test.log.part
      - mv .task/test.log.part .task/test.log

  update:
    desc: Bump the flake inputs, and every crate as far as Cargo.toml allows
    cmds:
      - nix flake update
      - cargo update
```

`pre` checks the formatting last, so a file the user has not saved in Neovim yet fails only that check, after the lint
and test results.

`test` uses `watchexec`, not go-task's own watch mode: watchexec ignores everything `.gitignore` lists (`target/`,
`node_modules/`, `.task/`), runs once at start, and restarts a run cleanly on a change, while go-task 3.53 cancels a
run on writes it then ignores and never restarts it. `test` holds `.task/test.lock` while it runs, so a second
`task test` in the same folder stops at once: two watchers ran every install twice at once and overwrote each other's
log.

TypeScript `Taskfile.yml`: the same `set`, `default`, `pre` and `test:once`; `test` watches `package.json` and
`tsconfig.json` instead of `Cargo.toml`; and these commands for the other tasks, one `cmds` entry per line.
`pnpm exec tsx --test` passes when a glob matches no file, so an empty suite does not break `pre`.

```text
  lint:             task: install
                    pnpm exec tsc
                    pnpm exec biome lint --error-on-warnings
  format:check:     task: install
                    pnpm exec biome format .
  test:integration: pnpm exec tsx --test 'tests/integration/*.test.ts'
  test:system:      pnpm exec tsx --test 'tests/system/*.test.ts'
  update:           nix flake update
                    pnpm update --latest '!@types/node'
                    pnpm update @types/node
```

`update` moves `@types/node` only within its major, the Node major of the flake (see TypeScript).

`install` runs only when `package.json` or `pnpm-lock.yaml` changed or `node_modules` is gone, so a save does not
reinstall the dependencies:

```yaml
  install:
    desc: Install the dependencies when they changed
    sources:
      - package.json
      - pnpm-lock.yaml
    generates:
      - node_modules/.modules.yaml
    cmds:
      - pnpm install --frozen-lockfile
```

`.gitignore`: `/result` and `/.task` (go-task's state and the test log), plus `/target` for Rust and
`/node_modules` for TypeScript.
