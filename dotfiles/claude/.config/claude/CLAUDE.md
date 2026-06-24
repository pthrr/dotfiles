# Orthodox

Orthodox C++ spirit generalized: **data and machine constraints first, language fashion second.** When this collides with "modern defaults", follow this section unless the task explicitly overrides.

## Principles

- Design from **data shape, size, access pattern, and rate** — not from noun taxonomies.
- **Plural-first APIs**; singular-only surfaces become painful later.
- Treat **hardware and runtime** (cache, branches, syscalls, allocation, I/O) as real; abstractions are for humans, not excuses.
- **Boring beats clever**; the cleverest line in a file is a liability.
- **Explicit over implicit**: no hidden control flow, allocation, or ordering.
- **Fast feedback**: keep build/test/edit loops short; multi-second routine loops are defects worth fixing when this code is touched.
- **Errors as values** at boundaries; do not drag vendor error types through the domain.

## Defaults to reject (override only with a short, measured rationale)

- Throwing / panicking / non-local exits for ordinary control flow.
- Runtime type dispatch and downcast chains as design; prefer tagged unions / closed sums.
- **Inheritance depth > 1**; prefer composition and plain data.
- Hidden allocation on latency-sensitive paths; **lifetime and allocation policy are part of the API**.
- Stream-style or fluent APIs that hide ordering; prefer plain calls with explicit arguments.
- Operators or magic protocols with non-obvious side effects.
- Patterns for two cases (visitor, factory, strategy, observer…) — **write the direct code** until repetition proves otherwise.
- Shared ownership as default; **default single owner**, visible transfer.
- Metaprogramming / macros / codegen / heavy reflection when straight code reads fine.
- **Type elision at boundaries**; spell types where callers cross a surface.
- Async stack for work that is not actually concurrent or I/O-bound.
- New dependencies for trivial helpers.
- Type-erased hot paths by default.

## How to work a task

- State **inputs/outputs, frequency, size, lifetime, and failure modes** before code.
- Ship the **dumbest** structure that fits; upgrade only with evidence.
- Make **ownership** obvious in names, types, or one `why` comment if the type cannot carry it.
- Prefer **values, arrays, tables, and plain functions** over behavior-heavy objects; **SoA over AoS** when iteration dominates.
- **One idiomatic way** per concern (one serializer style, one error style, …).
- **Handle errors at the source**; **recover at the boundary toward the user**; no silent swallow; no opaque error tunnels.

## CLI / composability

- Prefer **small tools** and stable **text streams** over bespoke IPC when fit is good.
- Prefer **stdin → stdout**, nonzero exit on failure, minimal flags.

# Software Architecture

- **Acyclic dependency graph**; core must not import outer layers.
- **One owner** per piece of mutable state; sharing is explicit and rare.
- **Pure / deterministic core**; I/O, time, randomness, and mutation at **edges**.
- Split **behavior change** from **refactors**; never mix in one undiffable step.
- **Objects** name ownership, invariants, and policy at **boundaries**; **bulk data** (arrays, SoA, indices) lives where **throughput** lives; cross in **batches**, not per-element virtual hops.
- **Invalidation strategy is part of the design**, not an afterthought; prefer **recompute** when cheaper than stale bugs.
- **Validate once** at trust boundaries; represent validated input as a **named type**.
- Write an **ADR** when a decision is stable, costly to reverse, and non-obvious.

# API Design

- **Narrow visibility**; widen only with intent and stability budget.
- **Stable names**; breaking changes need **migration + timeline**.
- Use **newtypes / wrappers** at boundaries for units, identities, and **illegal states unrepresentable** with raw scalars.
- Pick **one error strategy per module**; at public edges prefer **structured** errors over opaque blobs.
- **Forward compatibility**: reserved fields, extensible enums — where wire/ABI longevity matters.
- **Defaults safe and strict**; loosen only deliberately.
- **Async / streaming** only when the problem is actually streaming, cancellation, or concurrency.
- **Deprecation:** announce, migration path, removal date; avoid silent behavior drift.
- Document: **purpose, inputs/outputs, errors/failures, preconditions**; complexity or latency when non-obvious.

# Code Organization

- Prefer **feature-oriented** trees over **layer-only** trees unless the repo already commits the opposite.
- **One primary exported concept per file** unless types are inseparable.
- **Colocate fast tests** with sources; reserve a **slow/integration** tree for heavy tests.
- **Generated code** lives in a dedicated place, never hand-edited.
- **Package / module cycles forbidden**; fix direction before adding files.

# Communication

- **Default synchronous** in-process calls when coupling and latency allow; add **async / message / event** seams only with a stated reason.
- Match pattern to need: **request/response** when the caller needs an answer; **fire-and-forget** only when loss is acceptable by spec.
- Every cross-boundary call: **timeout**, **bounded retries**, **idempotency** or dedup story where retries exist.
- **Backpressure** explicit (block, drop policy, queue limits) — never unbounded silent buffers as design.

# Performance

- **No claim without numbers**; **no optimization without profile** (wall + counters when unclear).
- **Hot loop owns memory layout and allocation** nearby; do not abstract over unknown allocation on hot paths.
- Lay out hot data for **sequential access**; **SoA** when fields have different access rates.
- **False sharing** will not appear as a named line in a profile — **pad or partition** independent hot writer lines.
- **Serial efficiency before scaling** cores out.
- **Floating-point:** default **bit-reproducible** ordering; **fast-math / reorder** only with explicit team-visible opt-in.
- **Integer overflow / narrowing:** explicit policy on security- or money-critical paths.

# Embedded and Real-Time

- **No dynamic allocation after init** on RT or safety-critical paths unless explicitly documented with budget.
- Reason in **WCET**, not average latency, for real-time paths.
- **Bound stacks, queues, loops, recursion**; prefer **no recursion** on hard RT paths.
- **ISRs minimal**; defer work; **ISR ↔ task shared state** uses the same care as threads.
- **MMIO:** know what **volatile** vs **barriers/fences** give on your target; do not substitute one for the other.
- **Fail loud:** watchdog / reset / assert policy documented for bring-up vs field.

# Testing

- Tests lock **observable behavior** and **public contracts** — not incidental implementation layout.
- Prefer **property / generative** tests when the rule is shorter than the example table.
- **Deterministic tests**; isolate time, I/O, and randomness with seams you control.
- **CI treats warnings and failing tests as blockers**; add **sanitizers / static analysis** when the stack supports them.
- **Flakes are bugs**; fix or quarantine with owner and deadline — never normalize silent retry in CI.

# Operations

- Define **log level semantics** for operators (what wakes a human vs what is noise) and **stick to them** project-wide.
- **Structured fields** over prose when machines must aggregate; **no secrets or PII** in logs and traces.
- **Health checks:** distinguish **alive** vs **ready** vs **deep health**.
- **Alert on user-visible symptoms**; each alert has a **runbook or ticket template**.
- **Feature flags / gradual rollout** for risky behavior changes; default off until vetted.
- **Timeouts and budgets** on outbound dependencies; **circuit breaking** policy explicit where cascading failure matters.
