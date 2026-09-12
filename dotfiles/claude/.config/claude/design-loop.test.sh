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
T() { jq -c -n --arg p "$PWD/$1" --argjson a "${2:-false}" '{cwd:$ENV.PWD,transcript_path:$p,stop_hook_active:$a}' | "$S" stop >/dev/null 2>&1; echo $?; }
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
mkS() {
    {
      jq -c -n '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"software-design"}}]}}'
      jq -c -n --arg t "$2" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'
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
chk "stop_hook_active bypasses" 0 "$(T bad.jsonl true)"
chk "injection on resume with skill is valid json" 0 "$(A resume "$PWD/bad.jsonl" | jq -e . >/dev/null 2>&1; echo $?)"
chk "injection on compact with skill is valid json" 0 "$(A compact "$PWD/bad.jsonl" | jq -e . >/dev/null 2>&1; echo $?)"
chk "injection carries the goal" 0 "$(A resume "$PWD/bad.jsonl" | jq -e '.hookSpecificOutput.additionalContext | contains("writes a manifest")' >/dev/null 2>&1; echo $?)"
chk "no injection on startup even with skill in prior transcript" "" "$(A startup "$PWD/bad.jsonl")"

echo "subdirectory writes (PLAN.md found by walking up)"
mkdir -p deep/nested
chk "write into subdir allowed" 0 "$(W "$PWD/deep/nested/x.rs")"
chk "write into src allowed" 0 "$(W "$PWD/src/x.rs")"

echo "repo boundary"
mkdir -p other/.git
chk "sibling repo not armed by parent PLAN.md" 2 "$(W "$PWD/other/x.rs")"

echo "ceiling: must be backed by a design: marker (skill loaded)"
mkS ceiling.jsonl "${RENDER/OPEN   -/OPEN   2  ceiling: single-threaded over disjoint ranges}"
chk "ceiling without marker blocks" 2 "$(T ceiling.jsonl)"
printf '// design: single-threaded, split per range if build latency matters\n' >>src/walk.rs
chk "ceiling with marker passes" 0 "$(T ceiling.jsonl)"
chk "render without ceiling unaffected" 0 "$(T good.jsonl)"

echo "misuse"
chk "unknown mode errors" 1 "$(echo '{}' | "$S" bogus >/dev/null 2>&1; echo $?)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
