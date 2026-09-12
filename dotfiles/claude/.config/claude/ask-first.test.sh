#!/usr/bin/env bash
# Tests for ask-first.sh. Run it directly: ./ask-first.test.sh
# Each case builds a synthetic transcript with one user message and asserts
# whether the hook allows (exit 0) or blocks (exit 2) the edit.

set -uo pipefail

S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ask-first.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

pass=0
fail=0
chk() {
    if [ "$2" = "$3" ]; then
        pass=$((pass + 1))
        printf '  ok    %s\n' "$1"
    else
        fail=$((fail + 1))
        printf '  FAIL  %s (expected %s, got %s)\n' "$1" "$2" "$3"
    fi
}

run() {
    local msg=$1
    local f=$work/t.jsonl
    if [ -n "$msg" ]; then
        jq -c -n --arg t "$msg" \
            '{type:"user",message:{content:[{type:"text",text:$t}]}}' >"$f"
    else
        : >"$f"
    fi
    jq -c -n --arg p "$f" '{transcript_path:$p, tool_input:{file_path:"/tmp/x"}}' \
        | "$S" >/dev/null 2>&1
    echo $?
}

run_tool_only() {
    local f=$work/t.jsonl
    {
        jq -c -n '{type:"user",message:{content:[{type:"text",text:"ok"}]}}'
        jq -c -n '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"x",content:"whatever"}]}}'
    } >"$f"
    jq -c -n --arg p "$f" '{transcript_path:$p, tool_input:{file_path:"/tmp/x"}}' \
        | "$S" >/dev/null 2>&1
    echo $?
}

run_missing() {
    jq -c -n '{tool_input:{file_path:"/tmp/x"}}' | "$S" >/dev/null 2>&1
    echo $?
}

echo "consent phrases"
for m in "yes" "ok" "y" "YES" "Ok" "Y" "Yes." "OK." "y." "yes go" "ok, do it" "ok great" "i think ok" "yes we can"; do
    chk "\"$m\" allows" 0 "$(run "$m")"
done

echo "no consent"
for m in "add feature X" "please fix" "refactor Foo" "how does this work?" "" "explain the code"; do
    chk "\"$m\" denies" 2 "$(run "$m")"
done

echo "word boundary"
chk "\"yesterday\" denies" 2 "$(run "yesterday I broke it")"
chk "\"okay\" denies (only 'ok' is on the list)" 2 "$(run "okay let me think")"
chk "\"folks\" denies" 2 "$(run "folks are watching")"
chk "\"broker\" denies" 2 "$(run "broker is down")"
chk "\"why not\" denies (internal y)" 2 "$(run "why not")"
chk "\"many\" denies (internal y)" 2 "$(run "many changes")"
chk "\"my\" denies (internal y)" 2 "$(run "my code broke")"

echo "history handling"
chk "consent stands across a trailing tool_result-only user message" 0 "$(run_tool_only)"

echo "missing transcript"
chk "no transcript denies" 2 "$(run_missing)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
