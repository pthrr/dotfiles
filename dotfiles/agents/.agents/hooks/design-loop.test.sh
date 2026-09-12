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
# the case that distinguishes "which plan governs" from "is any plan open".
Tc() { jq -c -n --arg c "$1" --arg p "$PWD/$2" --argjson a "${3:-false}" '{cwd:$c,transcript_path:$p,stop_hook_active:$a}' | "$S" stop >/dev/null 2>&1; echo $?; }
A() {
    local src=${1:-startup}
    local tp=${2:-}
    jq -c -n --arg s "$src" --arg p "$tp" '
        {cwd:$ENV.PWD, source:$s} + (if $p == "" then {} else {transcript_path:$p} end)
    ' | "$S" activate 2>/dev/null
}
# mk writes a plain text-only transcript. mkS prepends a Skill tool_use that
# loads the software-design skill, which is what arms the strict render check.
mk()  { jq -c -n --arg t "$2" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}' >"$1"; }
# Arming is scoped to what the turn wrote, so a transcript has to contain a
# write for the loop to be running at all. $3 overrides which file, for the
# nested-plan cases; the default sits in the work tree's own plan.
mkS() {
    local writePath=${3:-$PWD/src/x.rs}
    {
      jq -c -n '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"software-design"}}]}}'
      jq -c -n --arg f "$writePath" '{type:"assistant",message:{content:[{type:"tool_use",name:"Write",input:{file_path:$f}}]}}'
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

printf 'a\nb\nc\n' >src/walk.rs
RENDER='ITERATION 1
GOAL   x

1 CODE ORGA
  src/walk.rs  w

2 PRIMITIVES
  type Foo {} inv own op src/walk.rs:2

3 INTERACTION
  main Foo - direct sync -

DELTA  x
OPEN   -'
mk  goodPlain.jsonl  "$RENDER"
mk  badPlain.jsonl   "all done, want me to continue?"
mkS good.jsonl       "$RENDER"
mkS bad.jsonl        "all done, want me to continue?"
mkS empty.jsonl      ""
mkS ghost.jsonl      "${RENDER//walk.rs:2/ghost.rs:2}"
mkS named.jsonl      "Sure, let's do src/my.rs.

$RENDER"
mkQ unflushed.jsonl  "$RENDER"
mkQ unflushedBad.jsonl "all done, want me to continue?"

echo "no PLAN.md"
chk "code write denied" 2 "$(W "$PWD/src/x.rs")"
chk "PLAN.md write allowed" 0 "$(W "$PWD/PLAN.md")"
chk "turn end free" 0 "$(T bad.jsonl)"
chk "no injection" "" "$(A)"

: >PLAN.md
echo "empty PLAN.md"
chk "code write denied" 2 "$(W "$PWD/src/x.rs")"
chk "turn end free" 0 "$(T bad.jsonl)"
chk "no injection" "" "$(A)"

printf '## Done when\n\nGiven a root, writes a manifest.\n' >PLAN.md
echo "non-empty PLAN.md, software-design skill NOT loaded"
chk "code write allowed" 0 "$(W "$PWD/src/x.rs")"
chk "PLAN.md edit allowed" 0 "$(W "$PWD/PLAN.md")"
chk "missing render unrestricted" 0 "$(T badPlain.jsonl)"
chk "good render still passes" 0 "$(T goodPlain.jsonl)"
chk "no injection on startup" "" "$(A startup)"
chk "no injection on resume without skill" "" "$(A resume "$PWD/badPlain.jsonl")"
chk "no injection on compact without skill" "" "$(A compact "$PWD/badPlain.jsonl")"

echo "non-empty PLAN.md, software-design skill loaded"
chk "missing render blocks" 2 "$(T bad.jsonl)"
chk "empty message blocks" 2 "$(T empty.jsonl)"
chk "good render passes" 0 "$(T good.jsonl)"
chk "unresolved file:line blocks" 2 "$(T ghost.jsonl)"
chk "bare filename does not block" 0 "$(T named.jsonl)"
chk "unflushed turn does not block" 0 "$(T unflushed.jsonl)"
chk "unflushed turn does not block after a bad turn" 0 "$(T unflushedBad.jsonl)"
chk "stop_hook_active bypasses" 0 "$(T bad.jsonl true)"
chk "injection on resume with skill is valid json" 0 "$(A resume "$PWD/bad.jsonl" | jq -e . >/dev/null 2>&1; echo $?)"
chk "injection on compact with skill is valid json" 0 "$(A compact "$PWD/bad.jsonl" | jq -e . >/dev/null 2>&1; echo $?)"
chk "injection carries the goal" 0 "$(A resume "$PWD/bad.jsonl" | jq -e '.hookSpecificOutput.additionalContext | contains("writes a manifest")' >/dev/null 2>&1; echo $?)"
chk "missing stack section falls back to an ask" 0 "$(A resume "$PWD/bad.jsonl" | jq -e '.hookSpecificOutput.additionalContext | contains("ask before cutting symbols")' >/dev/null 2>&1; echo $?)"
printf '\n## Stack\n\nRust 1.83, cargo, cargo test, linux x86_64, no new deps.\n' >>PLAN.md
chk "injection carries the stack" 0 "$(A resume "$PWD/bad.jsonl" | jq -e '.hookSpecificOutput.additionalContext | contains("Rust 1.83, cargo")' >/dev/null 2>&1; echo $?)"
chk "goal survives a second section" 0 "$(A resume "$PWD/bad.jsonl" | jq -e '.hookSpecificOutput.additionalContext | contains("writes a manifest")' >/dev/null 2>&1; echo $?)"
chk "no injection on startup even with skill in prior transcript" "" "$(A startup "$PWD/bad.jsonl")"

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
# The same write, from a session rooted in an unrelated repo. This is the shape
# the fallback actually failed on: the target is inside the armed project, the
# denial cited a PLAN.md belonging to somewhere else entirely.
mkdir -p elsewhere/.git
chk "new subtree judged by target, not by a foreign cwd" 0 "$(Wc "$PWD/elsewhere" "$PWD/fresh/x.rs")"
chk "existing subtree judged by target, not by a foreign cwd" 0 "$(Wc "$PWD/elsewhere" "$PWD/src/x.rs")"

echo "repo boundary"
mkdir -p other/.git
chk "sibling repo not armed by parent PLAN.md" 2 "$(W "$PWD/other/x.rs")"
# Same boundary, reached through a directory that does not exist yet.
chk "sibling repo boundary holds for a new subtree" 2 "$(W "$PWD/other/fresh/x.rs")"

echo "ceiling: must be backed by a design: marker (skill loaded)"
mkS ceiling.jsonl "${RENDER/OPEN   -/OPEN   2  ceiling: single-threaded over disjoint ranges}"
chk "ceiling without marker blocks" 2 "$(T ceiling.jsonl)"
printf '// design: single-threaded, split per range if build latency matters\n' >>src/walk.rs
chk "ceiling with marker passes" 0 "$(T ceiling.jsonl)"
chk "render without ceiling unaffected" 0 "$(T good.jsonl)"

echo "clustered axis 2 (path on the header, rows cite :<line>)"
# CLUSTER is the shape the skill actually prescribes: the path appears once on
# the cluster header and each row under it carries a bare :<line>.
CLUSTER='ITERATION 1
GOAL   x

1 CODE ORGA
  src/walk.rs  w

2 PRIMITIVES
  src/walk.rs  uses  -
    :2   type  Foo  {}
         !  holds
    :3   fn    bar  () -> Foo
         !  holds

3 INTERACTION
  main Foo - direct sync -

DELTA  x
OPEN   -'
mkS cluster.jsonl     "$CLUSTER"
mkS clusterGhost.jsonl "${CLUSTER//src\/walk.rs  uses/src\/ghost.rs  uses}"
mkS clusterDeep.jsonl  "${CLUSTER//:3   fn    bar/:99  fn    bar}"
mkS clusterOrphan.jsonl "${CLUSTER//  src\/walk.rs  uses  -/  uses  -}"
# A path in `1 CODE ORGA` must not act as the header for an orphaned row.
chk "clustered render passes" 0 "$(T cluster.jsonl)"
chk "unresolved cluster header blocks" 2 "$(T clusterGhost.jsonl)"
chk "line past EOF under a good header blocks" 2 "$(T clusterDeep.jsonl)"
chk "row with no cluster header blocks" 2 "$(T clusterOrphan.jsonl)"
chk "flat file:line rows still pass" 0 "$(T good.jsonl)"

echo "closed marker releases the render, not the write gate"
# The design is accepted: implementation may proceed and turn ends go free, but
# the write gate must stay standing. Emptying PLAN.md would do the opposite.
unmark() { grep -viE '^ {0,3}##[[:space:]]+closed' PLAN.md >PLAN.tmp && mv PLAN.tmp PLAN.md; grep -v '## Closed' PLAN.md >PLAN.tmp && mv PLAN.tmp PLAN.md; }

printf '\n## Closed\n' >>PLAN.md
chk "closed marker frees turn ends" 0 "$(T bad.jsonl)"
chk "closed marker keeps writes allowed" 0 "$(W "$PWD/src/x.rs")"
chk "closed marker tolerates a good render" 0 "$(T good.jsonl)"
unmark
chk "render required again once the marker is gone" 2 "$(T bad.jsonl)"

# Typed by hand, so the forgiving cases have to actually work.
printf '\n## closed\n' >>PLAN.md
chk "lowercase releases" 0 "$(T bad.jsonl)"
unmark
printf '\n##   CLOSED  \n' >>PLAN.md
chk "loose spacing and caps release" 0 "$(T bad.jsonl)"
unmark
printf '\n## Closed 2026-09-20 accepted\n' >>PLAN.md
chk "trailing note still releases" 0 "$(T bad.jsonl)"
unmark

# Near misses must not disarm the loop: a false release is the silent direction.
printf '\n## Closing thoughts\n' >>PLAN.md
chk "'## Closing thoughts' does not release" 2 "$(T bad.jsonl)"
unmark
printf '\n## Closedish\n' >>PLAN.md
chk "'## Closedish' does not release" 2 "$(T bad.jsonl)"
unmark
printf '\nthe design is closed\n' >>PLAN.md
chk "the word in prose does not release" 2 "$(T bad.jsonl)"
unmark
# A PLAN.md that documents how to close the loop must not thereby close it.
# CommonMark reads 4+ leading spaces as a code block, not a heading.
printf '\nEnding the loop is one line:\n\n    ## Closed\n\n...not written yet.\n' >>PLAN.md
chk "an indented code-block example does not release" 2 "$(T bad.jsonl)"
unmark
printf '\n\t## Closed\n' >>PLAN.md
chk "a tab-indented example does not release" 2 "$(T bad.jsonl)"
unmark
# 0-3 spaces is still a heading per CommonMark, so it still releases.
printf '\n   ## Closed\n' >>PLAN.md
chk "three leading spaces still releases" 0 "$(T bad.jsonl)"
unmark
chk "render required after every near miss" 2 "$(T bad.jsonl)"

echo "arming is scoped to what the turn wrote"
# Resolution stays gitignore-shaped: the nearest plan above a path governs it.
# Arming asks whether THAT plan is open — not whether any plan anywhere is.
# Start from a known state: the section above leaves the root plan open.
unmark; printf '\n## Closed\n' >>PLAN.md
mkdir -p nested/deep
printf '## Done when\n\nnested work.\n' >nested/deep/PLAN.md
mkS nestedBad.jsonl  "all done, want me to continue?" "$PWD/nested/deep/x.rs"
mkS nestedGood.jsonl "$RENDER"                        "$PWD/nested/deep/x.rs"

chk "writing into the open subtree blocks" 2 "$(T nestedBad.jsonl)"
chk "blocks from inside it too" 2 "$(Tc "$PWD/nested/deep" nestedBad.jsonl)"
chk "a good render passes there" 0 "$(T nestedGood.jsonl)"
# The case the whole change exists for: unrelated work while a subtree loop is
# open owes nothing, because the plan governing what was written is closed.
chk "writing outside it owes no render" 0 "$(T bad.jsonl)"
chk "writing outside it, from inside it, still owes nothing" 0 "$(Tc "$PWD/nested/deep" bad.jsonl)"
# A turn that wrote nothing is not design work either.
mkS noWrites.jsonl "just answering a question"
jq -c 'select(.message.content[0].name != "Write")' noWrites.jsonl >noWrites.tmp && mv noWrites.tmp noWrites.jsonl
chk "a turn that wrote nothing owes nothing" 0 "$(T noWrites.jsonl)"

printf '\n## Closed\n' >>nested/deep/PLAN.md
chk "closing the subtree frees it" 0 "$(T nestedBad.jsonl)"
rm -rf nested

echo "PROBLEM is a valid render too (loop 1 under an open plan)"
PROBLEM_BLOCK='PROBLEM 1
DONE WHEN  given a root, writes a manifest.
IN / OUT   thing  shape  size  rate  life  owner  checked by
BUDGETS    unbounded, accepted
FAILURES   missing input -> refuse to start
NON-GOALS  anything else
STACK      Rust 1.98  cargo  cargo test  linux  pinned
EXISTING   nothing yet
UNKNOWNS   spike  whether it links'
# The writes have to land in the open subtree, or the hook exits before it ever
# looks at the render's shape and these pass for the wrong reason.
mkdir -p nested/deep
printf '## Done when\n\nnested work.\n' >nested/deep/PLAN.md
mkS problem.jsonl     "$PROBLEM_BLOCK" "$PWD/nested/deep/x.rs"
# A PROBLEM block cites evidence in prose; those are not rows read off disk.
mkS problemCite.jsonl "${PROBLEM_BLOCK/nothing yet/see module.nix:9999 and ghost.rs:2}" \
                      "$PWD/nested/deep/x.rs"
chk "PROBLEM render accepted" 0 "$(T problem.jsonl)"
chk "PROBLEM render is not held to citations" 0 "$(T problemCite.jsonl)"
chk "neither shape still blocks" 2 "$(T nestedBad.jsonl)"
rm -rf nested

echo "## Finished re-arms the write gate"
unmark
printf '## Done when\n\nGiven a root, writes a manifest.\n' >PLAN.md
chk "open plan allows writes" 0 "$(W "$PWD/src/x.rs")"
printf '\n## Closed\n' >>PLAN.md
chk "closed plan allows writes" 0 "$(W "$PWD/src/x.rs")"
printf '\n## Finished\n' >>PLAN.md
chk "finished plan DENIES writes" 2 "$(W "$PWD/src/x.rs")"
chk "finished plan denies a brand-new subtree too" 2 "$(W "$PWD/brandnew/y.rs")"
chk "PLAN.md itself stays writable, so the next problem can be written" 0 "$(W "$PWD/PLAN.md")"
chk "finished frees turn ends like closed" 0 "$(T bad.jsonl)"
chk "finished wins over closed when both present" 2 "$(W "$PWD/src/x.rs")"
# The denial has to carry the old goal, or the model cannot tell a follow-up
# from a new problem — that is the whole reason the gate exists.
den=$(jq -c -n --arg f "$PWD/src/x.rs" '{cwd:$ENV.PWD,tool_input:{file_path:$f}}' | "$S" pre-write 2>&1 >/dev/null)
chk "denial names the marker" 0 "$(grep -q '## Finished' <<<"$den"; echo $?)"
chk "denial quotes the old goal" 0 "$(grep -q 'writes a manifest' <<<"$den"; echo $?)"
chk "denial offers both routes" 0 "$(grep -q 'delete the ## Finished' <<<"$den" && grep -q 'rewrite PLAN.md' <<<"$den"; echo $?)"
# SessionStart must surface the goal on a FRESH session, which is the turn the
# old behaviour missed entirely.
chk "startup injects for a finished plan, even with no skill loaded" 0 \
  "$(A startup "$PWD/badPlain.jsonl" | jq -e '.hookSpecificOutput.additionalContext | contains("writes a manifest")' >/dev/null 2>&1; echo $?)"
chk "injection warns against inheriting authorisation" 0 \
  "$(A startup "$PWD/badPlain.jsonl" | jq -e '.hookSpecificOutput.additionalContext | contains("different problem")' >/dev/null 2>&1; echo $?)"
# Rewriting PLAN.md without the marker is how the next task starts.
printf '## Done when\n\nA different problem entirely.\n' >PLAN.md
chk "rewritten plan unlocks writes again" 0 "$(W "$PWD/src/x.rs")"
chk "rewritten plan owes a render again" 2 "$(T bad.jsonl)"

echo "## Finished must not collide with ## Done when"
printf '## Done when\n\nGiven a root, writes a manifest.\n' >PLAN.md
chk "'## Done when' alone does not finish the plan" 0 "$(W "$PWD/src/x.rs")"
printf '\n## Done\n' >>PLAN.md
chk "a bare '## Done' does not finish it either" 0 "$(W "$PWD/src/x.rs")"
printf '\n## Finishing touches\n' >>PLAN.md
chk "'## Finishing touches' does not finish it" 0 "$(W "$PWD/src/x.rs")"
printf '\nTo end it write:\n\n    ## Finished\n' >>PLAN.md
chk "an indented example does not finish it" 0 "$(W "$PWD/src/x.rs")"
printf '\n## Finished 2026-09-20 shipped\n' >>PLAN.md
chk "a trailing note still finishes it" 2 "$(W "$PWD/src/x.rs")"

echo "misuse"
chk "unknown mode errors" 1 "$(echo '{}' | "$S" bogus >/dev/null 2>&1; echo $?)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
