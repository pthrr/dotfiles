---
when: "*.rs */Cargo.toml */.cargo/config.toml"
commands: "cargo"
---

# Rust

- **`pub(crate)` used to share code, not to expose a boundary.** Fine on a type
  with a written invariant above it — shared crate vocabulary is what it is for. A
  smell on a bare helper function: move that to the module which owns the data.
  Same for `pub(super)` and `pub(in path)`.
- Minimize `#[allow(...)]` statements
- `lib.rs` and `mod.rs` only contain module declarations and `pub use` re-exports
- Only use `mod.rs`-style for modules
- The project's committed `.cargo/config.toml` sets the 7-day cool-off:
  `global-min-publish-age = "7 days"` under `[registry]`. Cargo 1.100+ then
  ignores versions published more recently, transitive ones included, unless
  `Cargo.lock` already has them, and never falls back to a younger one.
- `cargo upgrade` (cargo-edit) ignores the cool-off: it reads the registry index
  itself and writes the newest version into `Cargo.toml`. So `update` runs only
  `cargo update`, and a major bump comes through Renovate, which applies the age
  itself, or through a deliberate edit of `Cargo.toml`.
