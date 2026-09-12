---
when: "*.rs"
---

# Rust

- **`pub(crate)` used to share code, not to expose a boundary.** Fine on a type
  with a written invariant above it — shared crate vocabulary is what it is for. A
  smell on a bare helper function: move that to the module which owns the data.
  Same for `pub(in path)`.
