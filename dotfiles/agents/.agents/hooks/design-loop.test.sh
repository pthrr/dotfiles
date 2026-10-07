#!/usr/bin/env bash
# Tests for design-loop.sh. Run it directly: ./design-loop.test.sh
# Each case pipes a synthetic hook payload and asserts the exit code, since
# exit 2 is the only thing that actually blocks the model.

set -uo pipefail

S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/design-loop.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work" || exit 1
mkdir -p src

pass=0
fail=0
chk() { # name expected actual
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
        printf '  ok    %s\n' "$1"
    else
        fail=$((fail + 1))
        printf '  FAIL  %s (expected %s, got %s)\n' "$1" "$2" "$3"
    fi
}

W() { jq -c -n --arg f "$1" '{cwd:$ENV.PWD,tool_input:{file_path:$f}}' | "$S" pre-write >/dev/null 2>&1; echo $?; }
# Wc is W with the session rooted somewhere other than the file being written —
# the case where gating on $cwd instead of the target silently judges the wrong
# project.
Wc() { jq -c -n --arg c "$1" --arg f "$2" '{cwd:$c,tool_input:{file_path:$f}}' | "$S" pre-write >/dev/null 2>&1; echo $?; }
T() { jq -c -n --arg p "$PWD/$1" --argjson a "${2:-false}" '{cwd:$ENV.PWD,transcript_path:$p,stop_hook_active:$a}' | "$S" stop >/dev/null 2>&1; echo $?; }
# Tc is T with the session rooted somewhere other than the work tree's root —
# the case that distinguishes "which plan governs" from "is any plan around".
Tc() { jq -c -n --arg c "$1" --arg p "$PWD/$2" --argjson a "${3:-false}" '{cwd:$c,transcript_path:$p,stop_hook_active:$a}' | "$S" stop >/dev/null 2>&1; echo $?; }
Terr() { jq -c -n --arg p "$PWD/$1" '{cwd:$ENV.PWD,transcript_path:$p,stop_hook_active:false}' | "$S" stop 2>&1 >/dev/null; }
A() {
    local src=${1:-startup}
    local tp=${2:-}
    jq -c -n --arg s "$src" --arg p "$tp" '
        {cwd:$ENV.PWD, source:$s} + (if $p == "" then {} else {transcript_path:$p} end)
    ' | "$S" activate 2>/dev/null
}
# The injected context for a source/transcript, or "" when nothing was injected.
Ax() { A "$@" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
has() { grep -q "$2" <<<"$1"; echo $?; }

# mk writes a plain text-only transcript. mkS prepends a Skill tool_use that
# loads the software-design skill, which is the only thing that arms the render
# checks — a file read never does.
mk()  { jq -c -n --arg t "$2" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}' >"$1"; }
mkS() {
    local writePath=${3:-$PWD/src/walk.rs}
    {
      jq -c -n '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"software-design"}}]}}'
      jq -c -n --arg f "$writePath" '{type:"assistant",message:{content:[{type:"tool_use",name:"Write",input:{file_path:$f}}]}}'
      jq -c -n --arg t "$2" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'
    } >"$1"
}
# mkN is mkS with no write at all: the turn only talked.
mkN() {
    {
      jq -c -n '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"software-design"}}]}}'
      jq -c -n --arg t "$2" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'
    } >"$1"
}
# mkQ ends on a turn whose only landed records are thinking and tool_use —
# what Stop reads when the turn's text record has not been flushed yet.
mkQ() {
    {
      jq -c -n '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"software-design"}}]}}'
      jq -c -n --arg t "$2" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'
      jq -c -n '{type:"user",message:{content:"and now?"}}'
      jq -c -n '{type:"assistant",message:{content:[{type:"thinking",thinking:"..."}]}}'
      jq -c -n '{type:"assistant",message:{content:[{type:"tool_use",name:"Bash",input:{command:"ls"}}]}}'
    } >"$1"
}

PLAN_GOAL='## Done when

Given a root, writes a manifest.
'
PLAN_STACK='
## Stack

Rust 1.83, cargo, cargo test, linux x86_64, no new deps.
'
plan=$PLAN_GOAL
writePlan() { printf '%s' "$plan" >PLAN.md; }

# The tree the renders below describe. Every row of a DESIGN block has to be true
# of this, which is the point of the whole check.
#
# The filler exists so a citation can be wrong without being past EOF: the line
# check is a window around the symbol, and in a six-line file every line falls
# inside it, so there would be no way to test a merely-wrong line.
{
    printf '/// chunk of a file\npub struct Chunk {\n}\npub fn split() -> Chunk {\n    todo!()\n}\n'
    for _ in $(seq 20); do printf '// filler\n'; done
} >src/walk.rs
printf 'pub struct Node {\n}\n' >src/node.rs

RENDER='DESIGN 1
GOAL   given a root, writes a manifest

1 CODE ORGA
  src/walk.rs                 byte ranges of one file

2 LOGICAL ARCH
  src/walk.rs  uses  -
    :2   type  Chunk  { }
         !  start + len <= file size
    :4   fn    split  () -> Chunk
         !  returns disjoint ranges covering the file

3 INTERACTION
  main -> split  direct call  sync  -  split

DELTA  cut Chunk and split
OPEN   -'

# Two clusters whose `uses` headers point at each other. The direction is stated
# in every render and used to be parsed and thrown away, so this rendered clean.
CYCLE_RENDER='DESIGN 2
GOAL   given a root, writes a manifest

1 CODE ORGA
  src/walk.rs                 byte ranges of one file
  src/node.rs                 one node of the manifest

2 LOGICAL ARCH
  src/walk.rs  uses  src/node.rs
    :2   type  Chunk  { }
         !  start + len <= file size
  src/node.rs  uses  src/walk.rs
    :1   type  Node  { }
         !  one entry, owned by the manifest

3 INTERACTION
  main -> split  direct call  sync  -  split

DELTA  cut Node
OPEN   -'

# The propose-turn shape. Unenforced by design: a turn that could not write owes
# no render anyway, so this only pins that it is not read as a broken DESIGN.
INTENT_BLOCK='INTENT 2
GOAL   given a root, writes a manifest

1 CODE ORGA
  src/node.rs  new  one node of the manifest

2 LOGICAL ARCH
  src/node.rs  uses  -
    type  Node { path: PathBuf, chunks: Vec<Chunk> }
      !  chunks are disjoint and cover the file

3 INTERACTION
  main -> Node::new  direct call  sync  -  Node

WHY    rung 3 — disjointness holds over the sequence, not over one Chunk
ASK    -'

PROBLEM_BLOCK='PROBLEM 1
DONE WHEN  given a root, writes a manifest.
IN / OUT   root  path  1  once  process  caller  exists check
BUDGETS    unbounded, accepted
FAILURES   missing root -> refuse to start
NON-GOALS  no incremental mode
STACK      Rust 1.83  cargo  cargo test  linux x86_64  no new deps
EXISTING   nothing yet
UNKNOWNS   spike  whether mmap beats read
ASK        does it follow symlinks?'

mk  goodPlain.jsonl  "$RENDER"
mk  badPlain.jsonl   "all done, want me to continue?"
mkS good.jsonl       "$RENDER"
mkS bad.jsonl        "all done, want me to continue?"
mkS empty.jsonl      ""
mkS named.jsonl      "Sure, let's do src/my.rs.

$RENDER"
mkQ unflushed.jsonl  "$RENDER"
mkQ unflushedBad.jsonl "all done, want me to continue?"
mkN noWrites.jsonl   "just answering a question"
mkN problem.jsonl    "$PROBLEM_BLOCK"
mkS problemWrote.jsonl "$PROBLEM_BLOCK"
# A PROBLEM block cites evidence in prose, and is held to none of it. In the
# problem loop no code exists yet — the write gate saw to that — so naming a path
# that is not there is the normal case, not a fabricated row.
mkN problemCite.jsonl "${PROBLEM_BLOCK/nothing yet/see src\/walk.rs:2}"
mkN problemGhost.jsonl "${PROBLEM_BLOCK/nothing yet/we would add src\/ghost.rs:2}"
# Each row of the design block is required. The key is spelled out rather than
# derived from the row: deriving it off the capitals turned `DELTA  cut Chunk`
# into DELTAC, and the check then looked for a fixture nobody had written.
while IFS='|' read -r key row; do
    mkS "no-${key}.jsonl" "${RENDER/$row/}"
done <<'ROWS'
GOAL|GOAL   given a root, writes a manifest
CODEORGA|1 CODE ORGA
LOGICALARCH|2 LOGICAL ARCH
INTERACTION|3 INTERACTION
DELTA|DELTA  cut Chunk and split
OPEN|OPEN   -
ROWS

echo "no PLAN.md: the problem loop"
chk "code write denied" 2 "$(W "$PWD/src/x.rs")"
chk "PLAN.md write allowed" 0 "$(W "$PWD/PLAN.md")"
chk "without the skill, turn ends are free" 0 "$(T badPlain.jsonl)"
chk "with the skill, a turn that wrote nothing still owes PROBLEM" 2 "$(T noWrites.jsonl)"
chk "a PROBLEM block satisfies it" 0 "$(T problem.jsonl)"
chk "a PROBLEM block may cite a real path" 0 "$(T problemCite.jsonl)"
chk "and a path that does not exist yet" 0 "$(T problemGhost.jsonl)"
# Nothing has been settled here, so there is nothing to design against: a DESIGN
# block describing the existing tree must not stand in for the problem loop.
chk "a DESIGN block does not satisfy the problem loop" 2 "$(T good.jsonl)"
chk "the denial says a PROBLEM block is what is owed" 0 "$(has "$(Terr good.jsonl)" 'must end with a PROBLEM block')"
chk "no injection" "" "$(A)"

echo "the sign-off turn: the plan it writes is found before the turn ends"
# Writing PLAN.md ends the problem loop, but not this turn's obligation: find_plan
# sees the file that was just written, so the turn is armed and still owes a
# render. A model that reads "the loop ends here" and signs off in prose is
# blocked at the moment it thinks it succeeded — which is why the skill says to
# end this one with the accepted PROBLEM block.
writePlan
mkS signoff.jsonl    "$PROBLEM_BLOCK"                "$PWD/PLAN.md"
mkS signoffProse.jsonl "Plan written. Shall we design?" "$PWD/PLAN.md"
chk "PROBLEM closes the sign-off turn" 0 "$(T signoff.jsonl)"
chk "prose does not" 2 "$(T signoffProse.jsonl)"
# Either shape is accepted there, since the plan now governs: going straight into
# the first design pass is legal too.
mkS signoffDesign.jsonl "$RENDER" "$PWD/PLAN.md"
chk "so does a first DESIGN pass" 0 "$(T signoffDesign.jsonl)"
rm -f PLAN.md

: >PLAN.md
echo "empty PLAN.md counts as absent"
chk "code write denied" 2 "$(W "$PWD/src/x.rs")"
chk "still the problem loop" 2 "$(T noWrites.jsonl)"
chk "no injection" "" "$(A)"

writePlan
echo "PLAN.md present, skill NOT loaded"
chk "code write allowed" 0 "$(W "$PWD/src/x.rs")"
chk "PLAN.md edit allowed" 0 "$(W "$PWD/PLAN.md")"
chk "missing render unrestricted" 0 "$(T badPlain.jsonl)"
chk "good render still passes" 0 "$(T goodPlain.jsonl)"
chk "no injection on startup" "" "$(A startup)"
chk "no injection on resume without the skill" "" "$(A resume "$PWD/badPlain.jsonl")"
chk "no injection on compact without the skill" "" "$(A compact "$PWD/badPlain.jsonl")"

echo "PLAN.md present, skill loaded: the design loop"
chk "missing render blocks" 2 "$(T bad.jsonl)"
chk "empty message blocks" 2 "$(T empty.jsonl)"
chk "good render passes" 0 "$(T good.jsonl)"
chk "bare filename in prose does not block" 0 "$(T named.jsonl)"
chk "unflushed turn does not block" 0 "$(T unflushed.jsonl)"
chk "unflushed turn does not block after a bad turn" 0 "$(T unflushedBad.jsonl)"
chk "stop_hook_active bypasses" 0 "$(T bad.jsonl true)"
chk "a turn that wrote nothing owes nothing" 0 "$(T noWrites.jsonl)"
# A nested subtree can still be in its own problem loop under a settled parent.
chk "PROBLEM is accepted where a plan governs" 0 "$(T problemWrote.jsonl)"
for key in GOAL CODEORGA LOGICALARCH INTERACTION DELTA OPEN; do
    chk "a render missing $key blocks" 2 "$(T "no-${key}.jsonl")"
done

echo "the DESIGN block is checked against the tree"
# 1 CODE ORGA names a file that was never cut.
mkS orgaGhost.jsonl "${RENDER/  src\/walk.rs                 byte ranges of one file/  src\/walk.rs   byte ranges
  src\/ghost.rs  never written}"
chk "1 CODE ORGA naming a missing file blocks" 2 "$(T orgaGhost.jsonl)"
chk "the denial names the missing path" 0 "$(has "$(Terr orgaGhost.jsonl)" 'nothing is there')"
# A directory counts: axis 1 cuts directories as well as files.
mkS orgaDir.jsonl "${RENDER/  src\/walk.rs                 byte ranges of one file/  src\/          the walk
  src\/walk.rs   byte ranges}"
chk "1 CODE ORGA may name a directory" 0 "$(T orgaDir.jsonl)"
# ...but axis 2 may not: a directory holds no declarations, so it does not
# register as a cluster header and every row beneath it is orphaned. The skill
# says so, because the denial talks about a missing header, not about the cause.
mkS archDirHeader.jsonl "${RENDER/  src\/walk.rs  uses  -/  src\/  uses  -}"
chk "a directory as a cluster header orphans its rows" 2 "$(T archDirHeader.jsonl)"
chk "and the denial points at the missing header" 0 "$(has "$(Terr archDirHeader.jsonl)" 'no cluster header')"
# 2 LOGICAL ARCH: the cluster header, the line, and the symbol all get checked.
mkS archGhostFile.jsonl "${RENDER/src\/walk.rs  uses  -/src\/ghost.rs  uses  -}"
mkS archPastEof.jsonl   "${RENDER/:4   fn    split/:99  fn    split}"
mkS archGhostSym.jsonl  "${RENDER/:4   fn    split  () -> Chunk/:4   fn    merge  () -> Chunk}"
mkS archOrphan.jsonl    "${RENDER/  src\/walk.rs  uses  -/  uses  -}"
chk "unresolved cluster header blocks" 2 "$(T archGhostFile.jsonl)"
chk "a line past EOF blocks" 2 "$(T archPastEof.jsonl)"
chk "a symbol that is not in the file blocks" 2 "$(T archGhostSym.jsonl)"
chk "the denial names the symbol" 0 "$(has "$(Terr archGhostSym.jsonl)" "declares 'merge'")"
# The path in 1 CODE ORGA must not act as the header for an orphaned row.
chk "a row with no cluster header blocks" 2 "$(T archOrphan.jsonl)"
# A :<line> below axis 2 is not a declaration and must not inherit the header.
mkS afterArch.jsonl "${RENDER/OPEN   -/OPEN   ask: see :99 in the notes}"
chk "a :<line> under OPEN is not read as a declaration" 0 "$(T afterArch.jsonl)"

echo "a cited line must locate the symbol"
# The point of citing a location. Before this, the line was only range-tested
# against the file length and the symbol was grepped file-wide, so neither fact
# constrained the other and `:1` on every row was a clean render.
mkS archWrongLine.jsonl "${RENDER/:4   fn    split/:18  fn    split}"
chk "a symbol cited at the wrong line blocks" 2 "$(T archWrongLine.jsonl)"
chk "the denial says where it actually is" 0 "$(has "$(Terr archWrongLine.jsonl)" 'found at :4')"
# The window: the invariant is a doc comment above the declaration, and attributes
# sit between, so either end of that small block is a fair citation.
mkS archDocLine.jsonl "${RENDER/:2   type  Chunk/:1   type  Chunk}"
chk "citing the doc comment line just above passes" 0 "$(T archDocLine.jsonl)"
# The symbol is the whole path, not its first word. Truncating at the first
# non-word character reduced `Chunk::split(...)` to `Chunk`, which matches the
# type declaration and every impl block, so the row located nothing in particular.
mkS archQualified.jsonl "${RENDER/:4   fn    split  () -> Chunk/:4   fn    Chunk::nope() -> Chunk}"
chk "a qualified symbol that is absent blocks" 2 "$(T archQualified.jsonl)"

echo "the uses graph must be acyclic"
mkS cycle.jsonl   "$CYCLE_RENDER"
mkS acyclic.jsonl "${CYCLE_RENDER/  src\/node.rs  uses  src\/walk.rs/  src\/node.rs  uses  -}"
chk "a cycle between two clusters blocks" 2 "$(T cycle.jsonl)"
chk "the denial says it is cyclic" 0 "$(has "$(Terr cycle.jsonl)" 'cyclic')"
chk "the same render acyclic passes" 0 "$(T acyclic.jsonl)"
chk "a single leaf cluster is trivially acyclic" 0 "$(T good.jsonl)"

echo "INTENT is the propose-turn shape"
mkN intent.jsonl "$INTENT_BLOCK"
chk "an INTENT turn that wrote nothing passes" 0 "$(T intent.jsonl)"
# The boundary that keeps INTENT from being a way around the tree check. It is not
# exempted like PROBLEM, it is simply never reached — so a turn that DID write and
# ends with it must be rejected, since neither marker set completes. Note the
# shared axis headings make this the one thing separating the two blocks: without
# `:<line>` rows, an INTENT cannot be checked against anything.
mkS intentWrote.jsonl "$INTENT_BLOCK"
chk "an INTENT turn that wrote is rejected" 2 "$(T intentWrote.jsonl)"
chk "the denial asks for a well-formed render" 0 "$(has "$(Terr intentWrote.jsonl)" 'no well-formed render')"

# INTENT shares all three axis headings with DESIGN, so the tree checks have to be
# scoped to the DESIGN block rather than to the headings. Unscoped, awk re-entered
# collection at INTENT's axis 1 and checked its PROPOSED paths for existence —
# rejecting the turn for the one thing INTENT exists to do.
mkS bothBlocks.jsonl "$RENDER

${INTENT_BLOCK/src\/node.rs  new/src\/ghost.rs  new}"
chk "a report followed by a proposal is not judged on the proposal" 0 "$(T bothBlocks.jsonl)"
# Order-independence: latching on ^DESIGN and clearing on ^INTENT has to work when
# the proposal comes first, or the tree check silently passes everything.
mkS bothBlocksRev.jsonl "${INTENT_BLOCK/src\/node.rs  new/src\/ghost.rs  new}

$RENDER"
chk "and not when the proposal comes first" 0 "$(T bothBlocksRev.jsonl)"
mkS bothBlocksBad.jsonl "${INTENT_BLOCK/src\/node.rs  new/src\/ghost.rs  new}

${RENDER/:2   type  Chunk/:18  type  Chunk}"
chk "the tree check still bites in that order" 2 "$(T bothBlocksBad.jsonl)"
# A proposal that reverses a reported edge must not manufacture a cycle across the
# two blocks: they are different graphs, one current and one hypothetical.
# DESIGN reports walk -> node; INTENT proposes node -> walk. Each graph alone is
# acyclic; merged they are not. Get the direction wrong here and the fixture has
# no cross-block cycle at all, so the test passes without testing anything.
mkS bothBlocksCycle.jsonl "${CYCLE_RENDER/  src\/node.rs  uses  src\/walk.rs/  src\/node.rs  uses  -}

${INTENT_BLOCK/  src\/node.rs  uses  -/  src\/node.rs  uses  src\/walk.rs}"
chk "a proposal reversing a reported edge is not a cycle" 0 "$(T bothBlocksCycle.jsonl)"

echo "the handover turn"
# It appends ## Accepted to PLAN.md, which arms it like any other write — so it owes
# a render, and the final DESIGN block is what it ends with. The old design had this
# turn write nothing and owe nothing, which made it indistinguishable from an idle
# turn; now it has a shape.
mkS handover.jsonl      "$RENDER"                        "$PWD/PLAN.md"
mkS handoverProse.jsonl "Handed over, 11 todo!() bodies" "$PWD/PLAN.md"
chk "writing ## Accepted arms the turn, and DESIGN closes it" 0 "$(T handover.jsonl)"
chk "prose does not close it" 2 "$(T handoverProse.jsonl)"

echo "ceiling: must be backed by a design: marker"
mkS ceiling.jsonl "${RENDER/OPEN   -/OPEN   ceiling: one walker thread}"
chk "ceiling without marker blocks" 2 "$(T ceiling.jsonl)"
printf '// design: one walker thread, split per subtree if the walk dominates\n' >>src/walk.rs
chk "ceiling with marker passes" 0 "$(T ceiling.jsonl)"
chk "render without ceiling unaffected" 0 "$(T good.jsonl)"

echo "ceiling: in a work tree uses a gitignore-aware search"
# The fixture is a real repo, because mktemp -d is not one: every ceiling test
# above exercises only the non-git fallback, so without this the primary path
# ships unverified.
mkdir -p gitproj/src
git -C gitproj init -q 2>/dev/null
printf '## Done when\n\ngit project.\n' >gitproj/PLAN.md
{
    printf '/// chunk of a file\npub struct Chunk {\n}\npub fn split() -> Chunk {\n    todo!()\n}\n'
    for _ in $(seq 20); do printf '// filler\n'; done
} >gitproj/src/walk.rs
mkS gitCeiling.jsonl "${RENDER/OPEN   -/OPEN   ceiling: one walker thread}" "$PWD/gitproj/src/walk.rs"
chk "no marker blocks in a work tree" 2 "$(Tc "$PWD/gitproj" gitCeiling.jsonl)"
# An ignored file does not carry the ledger. This is the case that distinguishes
# the two branches: the recursive fallback would find this marker and pass.
printf 'vendor/\n' >gitproj/.gitignore
mkdir -p gitproj/vendor
printf '// design: ignored trees do not count\n' >gitproj/vendor/big.rs
chk "a marker in an ignored file still blocks" 2 "$(Tc "$PWD/gitproj" gitCeiling.jsonl)"
# Untracked-but-not-ignored is exactly what the loop just wrote, so it must count.
printf '// design: one walker thread, split per subtree if the walk dominates\n' >>gitproj/src/walk.rs
chk "a marker in an untracked source file passes" 0 "$(Tc "$PWD/gitproj" gitCeiling.jsonl)"

echo "SessionStart re-injects the design loop across a compaction"
ctx=$(Ax resume "$PWD/bad.jsonl")
chk "injection on resume is valid json" 0 "$(A resume "$PWD/bad.jsonl" | jq -e . >/dev/null 2>&1; echo $?)"
chk "injection on compact is valid json" 0 "$(A compact "$PWD/bad.jsonl" | jq -e . >/dev/null 2>&1; echo $?)"
chk "injection carries the goal" 0 "$(has "$ctx" 'writes a manifest')"
chk "injection names all three dimensions" 0 "$(has "$ctx" '1 CODE ORGA / 2 LOGICAL ARCH / 3 INTERACTION')"
chk "injection names the write-first rule" 0 "$(has "$ctx" 'Write the files and the declarations FIRST')"
chk "injection names the acyclicity check" 0 "$(has "$ctx" 'must be acyclic')"
chk "injection names the two-turn cadence" 0 "$(has "$ctx" 'INTENT shape')"
chk "injection says implementation is the user's" 0 "$(has "$ctx" "user's, in their own session")"
chk "injection says nothing in PLAN.md releases the loop" 0 "$(has "$ctx" 'nothing you write into PLAN.md releases it')"
# The handover rule has to survive a compaction too: the old text said there was
# nothing to write into PLAN.md, which is the opposite of what the sign-off now does.
chk "injection names the ## Accepted handover" 0 "$(has "$ctx" '## Accepted')"
chk "missing stack falls back to an ask" 0 "$(has "$ctx" 'ask before cutting symbols')"
plan=$PLAN_GOAL$PLAN_STACK; writePlan
ctx=$(Ax resume "$PWD/bad.jsonl")
chk "injection carries the stack" 0 "$(has "$ctx" 'Rust 1.83, cargo')"
chk "goal survives a second section" 0 "$(has "$ctx" 'writes a manifest')"
# A fresh session is where the user implements. Re-arming there would re-enter
# the loop they were handed the tree out of.
chk "no injection on startup, even with the skill in the prior transcript" "" "$(A startup "$PWD/bad.jsonl")"
chk "no injection on an unrecognised source" "" "$(A clear "$PWD/bad.jsonl")"

echo "no marker in PLAN.md changes anything"
# '## Accepted' is the record the handover appends. It is in this list on purpose:
# it must behave exactly like a heading nobody reads, or it is '## Closed' again —
# a line that once said "implement freely" and kept saying it for unrelated work.
for marker in '## Closed' '## Finished' '## Implementing' '## Done' '## Accepted'; do
    printf '%s\n%s\n' "$plan" "$marker" >PLAN.md
    chk "'$marker' does not release the render" 2 "$(T bad.jsonl)"
    chk "'$marker' does not deny writes" 0 "$(W "$PWD/src/x.rs")"
done
writePlan
# Emptying it is not a release either: pre-write tests -s, so an empty plan
# denies every write instead of freeing the tree.
: >PLAN.md
chk "emptying PLAN.md seals the tree rather than releasing it" 2 "$(W "$PWD/src/x.rs")"
writePlan

echo "subdirectory writes (PLAN.md found by walking up)"
mkdir -p deep/nested
chk "write into subdir allowed" 0 "$(W "$PWD/deep/nested/x.rs")"
chk "write into src allowed" 0 "$(W "$PWD/src/x.rs")"
# The first write into a new subtree is the write that creates it. Gating on the
# directory already existing sent the walk off to $cwd and judged whatever
# project the session happened to be sitting in instead of the target's.
chk "write into not-yet-created dir allowed" 0 "$(W "$PWD/fresh/x.rs")"
chk "write into not-yet-created nested dir allowed" 0 "$(W "$PWD/fresh/deeper/x.rs")"
chk "relative path resolves against cwd" 0 "$(W "src/x.rs")"
chk "bare filename resolves against cwd" 0 "$(W "x.rs")"
mkdir -p elsewhere/.git
chk "new subtree judged by target, not by a foreign cwd" 0 "$(Wc "$PWD/elsewhere" "$PWD/fresh/x.rs")"
chk "existing subtree judged by target, not by a foreign cwd" 0 "$(Wc "$PWD/elsewhere" "$PWD/src/x.rs")"

echo "the harness whitelist"
# Whole trees, so config and state are both exempt, not just the memory and
# scratch paths that forced the change.
for p in \
    "$HOME/.claude/projects/a-slug/memory/a-fact.md" \
    "$HOME/.claude/settings.json" \
    "$HOME/.codex/config.toml" \
    "$HOME/.codex/memories/x.md" \
    "$HOME/.agents/skills/local/SKILL.md" \
    "$HOME/.config/opencode/opencode.json" \
    "$HOME/.local/share/opencode/storage/x.json" \
    "${TMPDIR:-/tmp}/claude-1000/a-slug/a-session/scratchpad/probe.sh" \
    /tmp/opencode/check.log
do
    chk "whitelisted: ${p#"$HOME"/}" 0 "$(W "$p")"
done
# A list, not a prefix rule — the neighbours have to stay gated, or the whitelist
# is really "anything starting with .claude".
chk "a sibling dotdir is still gated" 2 "$(W "$HOME/.claudex/x.md")"
chk "a HOME-level dotfile is still gated" 2 "$(W "$HOME/.example.conf.yml")"
chk "a plain tmp dir is still gated" 2 "$(W "/tmp/scratchpad/a.sh")"
chk "another harness tmp root is still gated" 2 "$(W "/tmp/codex-bwrap-synthetic-mount-targets-1000/x")"

echo "repo boundary"
mkdir -p other/.git
chk "sibling repo not armed by parent PLAN.md" 2 "$(W "$PWD/other/x.rs")"
chk "sibling repo boundary holds for a new subtree" 2 "$(W "$PWD/other/fresh/x.rs")"

echo "arming is scoped to what the turn wrote"
mkdir -p nested/deep
printf '## Done when\n\nnested work.\n' >nested/deep/PLAN.md
mkS nestedBad.jsonl  "all done, want me to continue?" "$PWD/nested/deep/x.rs"
mkS nestedGood.jsonl "$RENDER"                        "$PWD/nested/deep/x.rs"
chk "writing into the nested plan blocks" 2 "$(T nestedBad.jsonl)"
chk "blocks from inside it too" 2 "$(Tc "$PWD/nested/deep" nestedBad.jsonl)"
chk "a good render passes there" 0 "$(T nestedGood.jsonl)"
# A write that lands outside every plan is not design work: the sibling checkout
# has its own .git, so the walk stops before it reaches this tree's plan.
mkS foreign.jsonl "all done, want me to continue?" "$PWD/other/x.rs"
chk "writing into a sibling repo owes no render" 0 "$(T foreign.jsonl)"
rm -rf nested

# Not a prose pin — an identifier shared across four files. Rename the skill and
# arming breaks silently: the Skill call succeeds, state.active never flips, every
# hook goes quiet, and nothing says so.
#
# Ten greps of SKILL.md's Enforcement sentences used to live here, on the theory
# that a phrase and the behaviour it describes could be asserted together. They
# went 0 for 2 on real drift and passed through five doc/hook divergences: a grep
# proves a sentence exists, which is not the same as its being true, so a hook
# changed to do something new leaves every stale phrase matching. Ten assertions
# that always pass read as coverage and are worse than none.
echo "the skill name is the same string in every file that depends on it"
AGENTS="$(dirname "$S")/.."
name=$(sed -n '2s/^name: //p' "$AGENTS/skills/software-design/SKILL.md")
chk "frontmatter declares a name" 0 "$([ -n "$name" ]; echo $?)"
chk "adapter.ts arms on that name" 0 "$(grep -qF "\"$name\"" "$AGENTS/hooks/adapter.ts"; echo $?)"
chk "design-loop.sh matches that name" 0 "$(grep -qF "\"$name\"" "$AGENTS/hooks/design-loop.sh"; echo $?)"
chk "the skill directory is named for it" 0 "$([ -d "$AGENTS/skills/$name" ]; echo $?)"

echo "misuse"
chk "unknown mode errors" 1 "$(echo '{}' | "$S" bogus >/dev/null 2>&1; echo $?)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
