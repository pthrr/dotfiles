#!/usr/bin/env bash
# Exercise the stateless policy used by every client adapter.
set -uo pipefail

S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/write-gate.sh"
# Approval checks need a project outside the explicitly exempt temporary trees.
work=$(realpath "$(mktemp -d /var/tmp/write-gate-test.XXXXXX)")
trap 'rm -rf "$work"' EXIT
cd "$work" || exit 1
mkdir -p src .git
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

PLAN='# Example

## Problem

The project needs a function producing the requested result.

## Changes

- `src/` — add the function and exercise its expected behavior
- `new/deep/file.rs` — create the nested module that provides the result

## Verify

Run the checks and inspect the resulting module.
'
printf '%s' "$PLAN" >PLAN.md
proposal=$(jq -cn --arg p "$work/PLAN.md" --arg h "$(sha256sum PLAN.md | cut -d' ' -f1)" \
    '{id:"version-1",path:$p,hash:$h,shown:true,approved:true}')
prompt=ok

payload() {
    jq -cn --arg c "$work" --arg f "$1" --arg t "${2:-Edit}" --arg p "$prompt" --argjson a "$proposal" \
        '{cwd:$c,tool_name:$t,tool_input:{file_path:$f},prompt:$p,proposal:$a}'
}

W() { payload "$@" | "$S" pre-write >/dev/null 2>&1; echo $?; }
T() {
    jq -cn --arg c "$work" --arg m "$1" --argjson w "${2:-[]}" --argjson a "$proposal" --argjson retry "${3:-false}" \
        '{cwd:$c,last_assistant_message:$m,plans_written:$w,proposal:$a,stop_hook_active:$retry}' |
        "$S" stop >/dev/null 2>&1
    echo $?
}

chk "exact ok allows listed writes" 0 "$(W "$work/src/file.rs")"

for prompt in yes y OK Ok 'ok ' ' ok' 'ok do 1 and 2' 'is this ok?' 'not ok' '' $'ok\n'; do
    chk "nonexact consent is denied: [$prompt]" 2 "$(W "$work/src/file.rs")"
done

prompt=ok
chk "unlisted file is denied" 2 "$(W "$work/README.md")"
chk "listed subtree may be created" 0 "$(W "$work/src/new/deep/file.rs")"
chk "listed nested file may be created" 0 "$(W "$work/new/deep/file.rs")"
chk "directory prefixes are not names" 2 "$(W "$work/src-other/file.rs")"
mkdir -p foreign/.git
chk "a nested repository has its own boundary" 2 "$(W "$work/foreign/file.rs")"

saved=$proposal
proposal=null
chk "ok without a proposal grants nothing" 2 "$(W "$work/src/file.rs")"
proposal=$(jq '.approved=false' <<<"$saved")
chk "shown is not approved" 2 "$(W "$work/src/file.rs")"
proposal=$(jq '.shown=false' <<<"$saved")
chk "approval requires prior presentation" 2 "$(W "$work/src/file.rs")"
proposal=$saved
printf '%s' "${PLAN/result/result, cached}" >PLAN.md
chk "changed plan requires a new approval" 2 "$(W "$work/src/file.rs")"
printf '%s' "$PLAN" >PLAN.md

prompt='please explain'

for path in \
    "$HOME/.claude/settings.json" \
    "$HOME/.codex/config.toml" \
    "$HOME/.agents/skills/local/SKILL.md" \
    "$HOME/.config/opencode/config.json" \
    "$HOME/.local/share/opencode/state.json" \
    /tmp/probe.sh /tmp/ordinary/project/deep/probe.sh \
    "$HOME/tmp/probe.sh" "$HOME/tmp/project/deep/probe.sh" \
    "$work/PLAN.md" "$work/new/PLAN.md"
do
    chk "free target: $path" 0 "$(W "$path")"
done

for path in "$HOME/.claudex/file" "$HOME/tmp-other/file" /tmp-other/file "$work/src/file.rs"; do
    chk "neighbor remains gated: $path" 2 "$(W "$path")"
done

chk "custom TMPDIR is not implicitly exempt" 2 "$(TMPDIR="$work/private-tmp" W "$work/private-tmp/claude-1000/probe")"

for directory in /tmp "$HOME/tmp" "$HOME/.claude"; do
    chk "shell cwd grants no exemption: $directory" 2 "$(W "$directory/.shell-command" Bash)"
done

prompt=ok
chk "approved shell call does not need a plan in its cwd" 0 "$(W /tmp/.shell-command Bash)"
written=$(jq -cn --arg p "$work/PLAN.md" '[$p]')
chk "an ordinary completion preserves an open batch" 0 "$(T 'Done for this turn.')"
chk "a written plan must be shown" 2 "$(T 'Plan written.' "$written")"
chk "a full presentation ends the turn" 0 "$(T "$PLAN" "$written")"
chk "a correction is not held repeatedly" 0 "$(T 'Plan written.' "$written" true)"
printf '%s' "${PLAN/add the function and exercise its expected behavior/fix it}" >PLAN.md
chk "an invalid plan is rejected even when presented" 2 "$(T "$(cat PLAN.md)" "$written")"
printf '%s' "$PLAN" >PLAN.md
rm -f PLAN.md
chk "a deleted plan owes no presentation" 0 "$(T 'Closed.' "$written")"
chk "a deleted plan grants no authority" 2 "$(W "$work/src/file.rs")"

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
