# Project setup

Read this for Start, and before changing `flake.nix`, `Taskfile.yml`, `Cargo.toml`, `package.json`, `tsconfig.json`
or `.gitignore`.

## Start

1. `git init` if the folder is not a repository yet.
2. Write `README.md`, `flake.nix`, `Taskfile.yml`, `.gitignore`, `Cargo.toml` or `package.json` and `tsconfig.json`,
   the roots (`lib.rs`, `main.rs`, the two test `main.rs` for Rust), the stubs, and the walking skeleton's contract
   and scenario test files.
3. `git add flake.nix`; a flake in a git repository ignores untracked files.
4. Rust: `nix develop -c cargo add --dev proptest`. TypeScript:
   `nix develop -c pnpm add -D typescript @types/node@<major> fast-check` (see TypeScript).
   Neither language has a formatting step; Neovim formats each file on its first save.
5. `nix develop -c task pre`, then `git add flake.lock`, which the first `nix develop` created. Afterwards, rewrite
   PLAN.md as the session plan.

## Rust

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

- `tsconfig.json` holds the compiler options from `~/.agents/rules/typescript.md`, plus `"include": ["src", "tests"]`.
- `package.json` holds `"type": "module"` and the `devEngines` entry from `~/.agents/rules/typescript.md`.
- The starting devDependencies are `typescript`, `@types/node@<major>` (as `~/.agents/rules/typescript.md` says) and
  `fast-check`.
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
          ];
        };
      }
    );
}
```

TypeScript `flake.nix`: the same without `rust-overlay` (no input, `pkgs = import nixpkgs { inherit system; };`) and
with `packages = [ pkgs.nodejs-slim pkgs.pnpm pkgs.go-task pkgs.watchexec ];` (`nodejs-slim` is Node without npm
and npx).

Rust `Taskfile.yml`:

```yaml
version: '3'

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

  test:integration:
    desc: Run the contract tests
    cmds:
      - cargo test --test integration

  test:system:
    desc: Run the end-to-end scenarios
    cmds:
      - cargo test --test system

  pre:
    desc: Lint and run both test suites (pre-commit)
    cmds:
      - task: lint
      - task: test:integration
      - task: test:system

  test:
    desc: Rerun pre on every change; the last complete run is in .task/test.log
    cmds:
      - watchexec --restart --watch src --watch tests --watch Cargo.toml -- task test:once

  test:once:
    desc: Run pre once and keep its result in .task/test.log
    cmds:
      - mkdir -p .task
      - touch .task/test.started
      - task pre 2>&1 | tee .task/test.log.part && echo PASS >> .task/test.log.part || echo FAIL >> .task/test.log.part
      - mv .task/test.log.part .task/test.log
```

`test` uses `watchexec`, not go-task's own watch mode: watchexec ignores everything `.gitignore` lists (`target/`,
`node_modules/`, `.task/`), runs once at start, and restarts a run cleanly on a change, while go-task 3.53 cancels a
run on writes it then ignores and never restarts it.

TypeScript `Taskfile.yml`: the same `set`, `default`, `pre` and `test:once`; `test` watches `package.json` and
`tsconfig.json` instead of `Cargo.toml`; and these commands for the other tasks, one `cmds` entry per line.
`node --test` passes when a glob matches no file, so an empty suite does not break `pre`.

```text
  lint:             pnpm install --frozen-lockfile
                    pnpm exec tsc
  test:integration: node --test 'tests/integration/*.test.ts'
  test:system:      node --test 'tests/system/*.test.ts'
```

`.gitignore`: `/result`, `/PLAN.md` and `/.task` (go-task's state and the test log), plus `/target` for Rust and
`/node_modules` for TypeScript.
