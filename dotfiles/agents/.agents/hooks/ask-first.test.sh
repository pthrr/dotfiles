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

# A human turn followed by a harness-injected one. The injected message carries
# its content as a bare string, not the text-part array typed input uses — that
# is the real on-disk shape, and the shape the old filter read as human speech.
# An empty $human leaves the injected message alone in the transcript.
run_injected() {
    local human=$1 injected=$2
    local f=$work/t.jsonl
    {
        [ -n "$human" ] && jq -c -n --arg t "$human" \
            '{type:"user",message:{content:[{type:"text",text:$t}]}}'
        jq -c -n --arg s "$injected" '{type:"user",message:{content:$s}}'
    } >"$f"
    jq -c -n --arg p "$f" '{transcript_path:$p, tool_input:{file_path:"/tmp/x"}}' \
        | "$S" >/dev/null 2>&1
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

# A background command exiting, a slash command, a `!` command: each lands a
# user-role message the human did not write, and each used to spend the consent
# they had just given.
echo "injected messages do not displace consent"
chk "task-notification" 0 "$(run_injected "ok" '<task-notification>
<status>completed</status>
<summary>Background command "home-manager switch" completed (exit code 0)</summary>
</task-notification>')"
chk "command-name" 0 "$(run_injected "ok" '<command-name>/simplify</command-name>')"
chk "local-command-caveat" 0 "$(run_injected "ok" '<local-command-caveat>caveat</local-command-caveat>')"
chk "local-command-stdout" 0 "$(run_injected "ok" '<local-command-stdout>done</local-command-stdout>')"

# The other half: injected text is attacker-shaped, because `!` command output is
# arbitrary. None of it may authorize an edit the human never approved.
echo "injected messages do not forge consent"
chk "\"ok\" in test output" 2 "$(run_injected "add feature X" '<local-command-stdout>test tokenize ... ok</local-command-stdout>')"
chk "a file named \"y\" in an ls" 2 "$(run_injected "add feature X" '<local-command-stdout>a.txt  y  z.txt</local-command-stdout>')"
chk "\"yes\" in a notification summary" 2 "$(run_injected "refactor Foo" '<task-notification><summary>yes it finished</summary></task-notification>')"
chk "a slash command named /yes" 2 "$(run_injected "refactor Foo" '<command-name>/yes-man</command-name>')"
chk "an injected message with no human turn at all" 2 "$(run_injected "" '<local-command-stdout>ok</local-command-stdout>')"

# Harness-owned trees skip consent entirely, checked before the transcript is even
# read — so they pass with a transcript that grants nothing, and with none at all.
runp() {
    local path=$1
    local f=$work/t.jsonl
    jq -c -n '{type:"user",message:{content:[{type:"text",text:"add feature X"}]}}' >"$f"
    jq -c -n --arg p "$f" --arg t "$path" '{transcript_path:$p, tool_input:{file_path:$t}}' \
        | "$S" >/dev/null 2>&1
    echo $?
}
echo "the harness whitelist bypasses consent"
for p in \
    "$HOME/.claude/projects/a-slug/memory/a-fact.md" \
    "$HOME/.claude/settings.json" \
    "$HOME/.codex/memories/x.md" \
    "$HOME/.aider/analytics.json" \
    "$HOME/.agents/skills/local/SKILL.md" \
    "$HOME/.config/opencode/opencode.json" \
    "$HOME/.local/share/opencode/storage/x.json" \
    "${TMPDIR:-/tmp}/claude-1000/a-slug/a-session/scratchpad/probe.sh" \
    /tmp/opencode/check.log
do
    chk "no consent needed: ${p#"$HOME"/}" 0 "$(runp "$p")"
done
chk "a sibling dotdir still needs consent" 2 "$(runp "$HOME/.claudex/x.md")"
chk "a repo path still needs consent" 2 "$(runp "$HOME/.dotfiles/README.md")"
chk "a plain tmp path still needs consent" 2 "$(runp /tmp/scratchpad/a.sh)"

echo "missing transcript"
chk "no transcript denies" 2 "$(run_missing)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
