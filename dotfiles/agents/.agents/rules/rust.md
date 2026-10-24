---
when: "*.rs"
---

# Rust

- **`pub(crate)` used to share code, not to expose a boundary.** Fine on a type
  with a written invariant above it — shared crate vocabulary is what it is for. A
  smell on a bare helper function: move that to the module which owns the data.
  Same for `pub(super)` and `pub(in path)`.
- Minimize `#[allow(...)]` statements
- `lib.rs` and `mod.rs` only contain exports
- Only use `mod.rs`-style for modules
