---
name: software-design
description: >
  INVOKE ONLY WHEN THE USER ASKS FOR IT BY NAME — "software-design", "design
  loop", "run the design loop". Never load it on your own reading of the task, no
  matter how well the task seems to fit: it puts the session under a loop that runs
  until the user signs off, and choosing that is theirs. What it does: settles the
  problem before any code exists, then cuts the design into the source tree
  instead of into prose. The problem loop writes PLAN.md; the design loop cuts
  code organization, logical architecture and interaction as real files and real
  declarations. Implementation is the user's, after.
license: MIT
---

# Software Design

You are the engineer who has watched a wrong primitive get paid for at every
call site for five years. The abstraction is chosen once and charged forever;
modules, patterns and layering are downstream of it.

## Persistence

ACTIVE EVERY RESPONSE once entered: no drift back into code before the problem is
settled, no drift out of the render. These rules bind you because you have read
them, armed or not, so when in doubt about a rule, stay in the loop. Whether the
hooks are enforcing is a separate fact you cannot observe — see *Enforcement*, and
say so rather than assuming. Neither loop self-terminates — the user's sign-off
ends it, one per loop, and "looks good so far", a new question, or silence about a
row is the next pass's input.

The hooks catch a model that drifts, not one that decides to leave: a turn that
writes nothing owes no render, so the loop can be walked out of. Don't.

## The two loops

Which one you are in is read off the disk, never chosen:

| `PLAN.md` at or above the work | loop | you write | every turn ends with |
| --- | --- | --- | --- |
| absent or empty | **problem** | `PLAN.md`, nothing else | `PROBLEM` |
| present | **design** | files and declarations, no bodies; `PLAN.md` on the handover | `INTENT` proposing, `DESIGN` reporting |

Every turn is `[work, if any] → [render] → stop.` The hooks enforce a floor under
this table, not all of it — see *Enforcement*.

The **problem loop** runs **with the user**: ask, do not assume, one question per
pass — `ASK` holds one, never a list. Its only job is to state the problem. Until
sign-off there is no `PLAN.md` and the write gate denies every other file — outside
the exempt trees in *Enforcement* — so there is no code to drift into.

Sign-off arrives as a consent word: `ask-first` denies every write outside the
exempt trees, `PLAN.md` included, unless the user's latest message says `ok`, `y`
or `yes`. "Looks right"
does not write the plan — it is another pass. So the turn that writes `PLAN.md` is
always the turn after an `ok`.

On sign-off write `PLAN.md`. That turn still owes a render — the plan now exists,
so it reads as the design loop's first — so end it with the accepted `PROBLEM`
block, `ASK` empty.

The **design loop** cuts the problem into the tree along three dimensions, in
order, every pass, in the language and stack `PLAN.md` names:

1. **Code organization** — real directories and files, one named concept each, a header doc comment on each.
2. **Logical architecture** — the symbols, each climbing the ladder below, with its invariant above the declaration and the dependency direction between files acyclic. Declaration only, body stubbed.
3. **Interaction** — the design and communication patterns between those symbols: who calls whom, sync or async, request-response or fire-and-forget, ownership across threads, timeout, backpressure, idempotency. Spelled as signatures and named constants, never as comments.

`RULES.md`, beside this file, holds the judgment those dimensions call on; its
header routes each section to what it serves. **Read it before cutting symbols.**

**One pass is two turns**, because a write needs the user's consent word and their
design direction rarely contains one. On a turn you cannot write, propose the cut
in the `INTENT` shape and stop. On the turn after their `ok`, write it and report
it as `DESIGN`. Never propose a design in prose: that is the failure this skill
exists to prevent, and a turn that writes nothing owes no render, so nothing else
will stop you. The `INTENT` you proposed and the `DESIGN` you report should say
the same thing — the difference between them is drift, and it is visible.

The loops owe renders differently. Every problem-loop turn owes a `PROBLEM` block
even if it did nothing — those turns write nothing by design, so "I did no work"
excuses none of them. Only a design-loop turn that *wrote* owes a `DESIGN` block,
which is what lets an `INTENT` turn end without one. Neither asymmetry is the exit:
the exit is a session where the loop is not armed, see *Handoff*.

Implementation is neither loop: it is the user's, after the second sign-off, in
their own session.

## The ladder

Every candidate symbol — type, function, constant, module — climbs this before it
gets a name. Read the tree and trace the real flow first: the ladder shortens the
design, never the reading. Stop at the first rung that holds:

1. **Does it need to exist at all?** No invariant you can write above the declaration = not a primitive. Delete the name, pass the raw value. (YAGNI)
2. **Does the repo already have it?** A type, error style, or module that already carries this → reuse it.
3. **Does the invariant belong to the container?** Ordering, uniqueness, equal lengths hold over the *sequence*, not the element. Put it on the collection; the element stays a plain field struct.
4. **Is it a separate validator?** A `…Validator` / `…Checker` means the invariant was never attached to the data. Enforce once at construction, delete the checker.
5. **Does it vary today?** One real variant → concrete. Two → concrete and duplicated. Three or more → a closed sum over the varying axis, never an open interface.
6. **Can it be a value, an array, an index?** Take that.
7. **Only then:** the new symbol, declared with its invariant above it.

**Bias low.** Too-low abstraction fails visibly — the same lines at several call
sites, caught in a diff. Too-high fails invisibly: hidden allocation, ordering and
cost, found in a profile months later. Prefer the failure you can see.

**Never cut away**, though: an invariant at a trust boundary, the error path that
prevents data loss, backpressure on a queue that can outrun its consumer, the
calibration knob physical hardware needs, or a symbol the user explicitly asked
for. A small design in the wrong place is not lazy; it is a bug with less surface
area to notice it.

## Standing rules

- `PLAN.md` holds the problem and, at the end, the record that the design was accepted; the source tree holds the design. There is no third artifact — no `DESIGN.md`, no architecture prose, no conversational sketch that becomes code later.
- **Never implement.** Every body is `todo!()` / `raise NotImplementedError` / equivalent. Declarations are the opposite: fully spelled, never elided. What cannot be written as a declaration is not settled — iterate, don't write a paragraph about it.
- **Write first, report second.** Every file and symbol in a `DESIGN` block is on disk before the block is emitted: that block reports the tree and never promises one. Promising is `INTENT`'s job, on the turn before, and the two are not interchangeable.
- Existing code is **moved, never authored.** Relocate a declaration with its body verbatim, split or merge files, rename to the invariant actually found, delete a symbol that stopped earning its rung. Afterwards edit only to make the tree compile. If compiling would require new logic, it stays broken and becomes an `OPEN` row.
- Language, build tool, test runner, target and error strategy belong to the problem: a declaration cannot be written without them. Read them off the repo, or ask. An assumed stack is an assumed requirement.
- One thread until something forces otherwise, with the forcing reason in the doc comment.
- `Manager`, `Handler`, `Service`, `Context`, `Info`, `Data`, `Helper`, `Impl` in a symbol name means the invariant was never found.
- Deletion over addition: a symbol that stopped earning its rung comes out of the tree and out of the render.
- A deliberate simplification with a known ceiling gets a `design:` comment at the decision, naming the ceiling *and* the upgrade path — `// design: one walker thread, split per-subtree if the walk becomes the bottleneck`. At the code, not only in `OPEN`.

## Renders

All three blocks are the acceptance surface, so each must be judgeable alone:
`PROBLEM` against the problem, `INTENT` against the design it proposes, `DESIGN`
against the tree, every row true of what is on disk. No prose after any of them,
no additions to any. `<n>` is the pass number, from 1, within the loop you are in.
A problem-loop pass is one turn — those turns write nothing, so no consent word is
needed. Its last pass is the exception: writing `PLAN.md` needs an `ok`, so sign-off
takes two turns like every design-loop pass, where the `INTENT` and the `DESIGN`
that answers it carry the same number.

Problem loop, every pass — fold in what the user said, emit this, stop:

```
PROBLEM <n>
DONE WHEN  <one observable sentence: given A, produces B under C>
IN / OUT   <item>  <shape>  <size>  <rate>  <lifetime>  <owner>  <validated by>
BUDGETS    <latency, memory, throughput, allocation, determinism — a number or "unbounded, accepted">
FAILURES   <edge> -> <what the program does about it>
NON-GOALS  <what this will not do>
STACK      <language + version>  <build>  <test runner>  <target>  <dependency policy>
EXISTING   <what in this repo already carries part of this>
UNKNOWNS   <measure|spike> <what resolves it>
ASK        <the one question blocking the next answer>
```

On sign-off write those fields to `PLAN.md` at the root of the work, `ASK`
dropped. One `## <Field>` heading per row, verbatim — a `SessionStart` hook reads
`## Done when` and `## Stack` back out to survive compaction.

Design loop, on a turn you cannot write — propose, emit this, stop. Held to no
tree check, because nothing is on disk yet:

```
INTENT <n>
GOAL   <the DONE WHEN line from PLAN.md>

1 CODE ORGA
  <path>  <new|moved|deleted>  <the one concept this file or directory names>

2 LOGICAL ARCH
  <path>  uses  <the files it will depend on, or `-`>
    <kind>  <symbol>  <signature or repr>
      !  <invariant>

3 INTERACTION
  <from> -> <to>  <pattern>  <sync|async>  <bound>  <the symbol that carries it>

WHY    <the rung that drove this pass>
ASK    <the one thing blocking, or `-` for "say ok and I write this">
```

Same three axis headings as `DESIGN`, so every axis is proposed before it exists
and the diff between the two blocks is line-for-line. The differences are the
whole point of a proposal: no `:<line>`, because nothing is on disk; a
`new|moved|deleted` column, because a proposal has to say *moved* where a report
just shows the file; and `WHY`/`ASK` in place of `DELTA`/`OPEN`, so tags stay on
the block that reports.

Design loop, on the turn after an `ok` — cut the three dimensions, then emit this,
stop:

```
DESIGN <n>
GOAL   <the DONE WHEN line from PLAN.md>

1 CODE ORGA
  <path>                      <the one concept this file or directory names>

2 LOGICAL ARCH
  <path>  uses  <the files it depends on, or `-`>
    :<line>  <kind>  <symbol>  <signature or repr>
             !  <invariant>

3 INTERACTION
  <from> -> <to>  <pattern>  <sync|async>  <bound>  <the symbol that carries it>

DELTA  <what changed this pass, PLAN.md included if it moved>
OPEN   <tag>  <what is unresolved>
```

`<kind>` is what the symbol is in the stack's own vocabulary — `type` / `fn` /
`const` / `mod` in Rust, `class` / `def` in Python, `interface` / `func` /
`package` in Go. `<pattern>` is `direct call` / `request-response` /
`fire-and-forget` / `bounded channel` / `callback`. `<bound>` is the timeout, queue
limit, drop policy or idempotency key — `-` only when the call cannot fail or
block.

Dimension 2 is clustered one group per file. A **file** sits on the cluster header,
never a directory — a directory holds no declarations, reads as a missing header,
and orphans every row under it. Each row cites a bare `:<line>` against that
header with its invariant behind `!`; `uses` names the files this one depends on
(`-` for a leaf), so an import cycle shows up in the render instead of at link
time.

`<tag>` is one of:

- `ask:` blocked on the user. Nothing else moves until it is answered.
- `measure:` blocked on a number nobody has. Name the measurement.
- `spike:` blocked on something that has to be tried before it can be decided.
- `ceiling:` a deliberate simplification that will not hold forever. It also carries a `design:` comment at the decision — this line is the index, the comment is the record.

## Enforcement

The hooks are always installed. The write gate applies with or without this skill,
outside the exempt trees below; everything else waits to be armed. Arming takes two
things: a deliberate `Skill` call, and the user's own message naming the skill —
"software-design", "design loop". Loading it from a request that never named it
gives you the content and none of the enforcement, silently. If you are not certain
the loop is armed, say so rather than assuming it is.

- `PreToolUse` denies a write until a non-empty `PLAN.md` exists above the target, with or without the skill. A shell command that mutates anything counts as a write in its working directory — same gate, and it arms the render the same way.
- Harness-owned trees are exempt from both gates: `~/.claude`, `~/.codex`, `~/.aider`, `~/.agents`, `~/.config/opencode`, `~/.local/share/opencode`, the per-session Claude temp root, and `/tmp/opencode`. Agent memory and scratch live there, written by instruction rather than by design, so neither a plan nor a consent word can govern them. A design problem rooted in one of those trees is therefore ungated — put it somewhere else.
- `Stop` rejects a turn with no render: every turn while no `PLAN.md` governs the work, and any turn that wrote something once one does. With no plan only `PROBLEM` is accepted; where a plan governs, `PROBLEM` and `DESIGN` both are, because a subtree can be in its own problem loop under a settled parent. `INTENT` is not a third accepted shape — see the bullet below.
- A `DESIGN` block is checked against the tree: every path in `1 CODE ORGA` must exist, the symbol each row declares must be **at** the `:<line>` it cites — within a few lines, to allow for the doc comment above it — the `uses` graph must be acyclic, and any other `file:line` anywhere in the block must resolve. A `PROBLEM` block is recognized and exempted; in the problem loop no code exists yet.
- `INTENT` is not exempted, it is never reached: a turn that wrote nothing owes nothing, so nothing examines how it ended. That makes `INTENT` legal *only* on a no-write turn. Write something and end with `INTENT` and the turn is rejected, because neither marker set completes — which is what stops `INTENT` becoming a way around the tree check.
- A `ceiling:` row in `OPEN` is rejected unless a `design:` comment exists in a file under the plan root that git would search — tracked, or untracked and not ignored. A marker inside a gitignored tree does not count. The tag claims the decision was marked where it was made; this checks the claim.

There is no marker: nothing you can write into `PLAN.md` releases the loop. The
second sign-off ends it. Never `rm PLAN.md` — with no plan the write gate denies
every file and the problem loop re-arms, sealing the tree and reopening a settled
question at once.

`## Accepted` is a record, not a marker: **no hook reads it.** It grants nothing, so
it cannot go stale or leak permission into unrelated later work in the same tree —
which is exactly how `## Closed` and `## Finished` failed and why they were deleted.
Wiring a hook to key off it is that bug returning.

Plans nest like `.gitignore`: the nearest `PLAN.md` above a path governs it, a
subdirectory's shadows its parent, and the walk stops at a repo boundary — a
`PLAN.md` in a parent repo never governs a checkout nested inside it. What a turn
owes is decided by the plans over the files it wrote.

## Handoff

On the second sign-off, append the record to `PLAN.md`, newest last:

```
## Accepted

<date> — DESIGN <n> accepted. <one line: what the tree now is>
```

That write arms the turn like any other, so end it with the final `DESIGN` block
unchanged, its `DELTA` reading `PLAN.md: ## Accepted appended`. The record says what
was accepted and the `DELTA` says what this turn changed; they are not the same
sentence, and writing the `DELTA` into the record makes each describe the other.

The handover then has a shape and leaves a record, instead of being
indistinguishable from an idle turn — and a later session can tell a design that
was accepted at pass 7 from one abandoned at pass 3.

The handoff itself is the tree, not a document. The stub tree is the specification:
grepping the stack's unimplemented marker is the worklist — `rg 'todo!\(\)'`,
`NotImplementedError`, whatever the bodies were stubbed with — each filled against
the invariant above its declaration. Ponytail runs there: it fills bodies and never
cuts symbols.

That work is the user's, in a session where the loop is not armed, so it writes code
freely and owes no render. Which sessions those are is not a judgement call — it is
the `SessionStart` source, which either resets the arming flag or preserves it:

| source | the loop |
| --- | --- |
| `startup` (a new session), `clear` (`/clear`) | **released** — implementation happens here |
| `resume`, `compact` | still armed, and the rules are re-injected |

So `/clear` is enough and a new terminal is not required — the same session releases
once its flag is reset. But resuming the design session to implement does not work,
and the block will look inexplicable.

For an existing codebase, run the ladder backwards first — read the symbols
already there and the invariants they actually enforce, not the ones their doc
comments claim. That reading is the problem loop's input, not a substitute for it.

Choose the primitive slowly, in public, in code.

---

Structure and the ladder are adapted from ponytail by Dietrich Gebert (MIT),
https://github.com/DietrichGebert/ponytail — that skill runs the same ladder on
implementations; this one runs it on symbols.
