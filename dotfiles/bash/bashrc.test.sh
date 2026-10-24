#!/usr/bin/env bash
# Dispatch tests for the agent-CLI wrappers in .bashrc. A stub of each binary
# records its arguments into a log, the rc is sourced in its own bash process
# with a fake HOME and a stub-first PATH, and every case asserts the last
# thing a bare or argumented invocation forwarded to the stub.

set -uo pipefail

S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.bashrc"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/stub" "$work/fakehome/.claude/projects" "$work/gitproj/src"
cd "$work" || exit 1

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

# claude and codex forward verbatim. The stubs label themselves by the path
# they were invoked through, so the combined log reads claude [...] / codex [...]
for bin in claude codex; do
    cat <<'EOF' >"$work/stub/$bin"
#!/usr/bin/env bash
printf '%s [%s]\n' "${0##*/}" "$*" >>"$STUB_LOG"
EOF
done

# opencode doubles as its own session backend: `session` prints whatever the
# case staged, everything else is a dispatch call to log.
cat <<'EOF' >"$work/stub/opencode"
#!/usr/bin/env bash
if [ "$1" = "session" ]; then
    printf '%s\n' "${STUB_SESSIONS:-[]}"
    exit 0
fi
printf '%s [%s]\n' "${0##*/}" "$*" >>"$STUB_LOG"
EOF
chmod --recursive u+x "$work/stub"

# The stubs append through STUB_LOG; the harness resets and reads the same
# variable, which is why it also rides into run()'s environment below.
STUB_LOG="$work/calls.log"

# slug_points_at turns a path into the claude projects dir its encoding maps
# to — part of the contract under test, so the fixture uses the same recipe
# the wrapper would.
slug_points_at() { # path -> $HOME projects dir
    local slug
    slug=$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '-')
    printf '%s\n' "$work/fakehome/.claude/projects/${slug}"
}
root_chat() { # path file: author a chat below a fake project dir
    dir=$(slug_points_at "$1")
    mkdir -p "$dir"
    printf '{}' >"$dir/$2.jsonl"
}

# run <command> [staged-session-json]: reset the log, then run the command the
# way a login shell would — rc sourced, environment pointed at fake HOME and
# the stubs. Only the stub log's last line is heard from.
run() {
    : >"$STUB_LOG"
    {
        printf 'source %s 2>/dev/null\n' "$S"
        printf '%s\n' "$1"
    } >"$work/case.sh"
    STUB_LOG="$STUB_LOG" \
        STUB_SESSIONS="${2:-}" \
        HOME="$work/fakehome" \
        PATH="$work/stub:/usr/bin:/bin" \
        bash "$work/case.sh" >/dev/null 2>&1
    tail -n 1 "$STUB_LOG"
}

echo "bare invocations"

chk "bare claude with no prior chat starts fresh" "claude []" "$(run 'claude')"

chk "bare claude inside an authored chat continues" "claude [--continue]" \
    "$(root_chat "$work" one; run 'claude')"
rm -rf "$(slug_points_at "$work")"

chk "bare claude with args passes through" "claude [--version]" \
    "$(root_chat "$work" one; run 'claude --version')"
rm -rf "$(slug_points_at "$work")"

chk "bare codex resumes the last thread" "codex [resume --last]" "$(run 'codex')"
chk "codex with args passes through" "codex [exec plan]" "$(run 'codex exec plan')"

chk "bare opencode with no sessions starts fresh" "opencode []" "$(run 'opencode')"

staged_foreign='[{"id":"ses_old","directory":"/elsewhere"}]'
chk "bare opencode ignores chats of other directories" "opencode []" \
    "$(run 'opencode' "$staged_foreign")"

staged_mixed=$(printf '[{"id":"ses_old","directory":"/elsewhere"},{"id":"ses_newest","directory":"%s"}]\n' "$work")
chk "bare opencode resumes a chat of this directory" "opencode [-s ses_newest]" \
    "$(run 'opencode' "$staged_mixed")"

chk "bare opencode with args passes through" "opencode [--help]" "$(run 'opencode --help')"

echo "claude keys the project at the git root"
# A repo fixture: root and subdirectory ship one project, so a chat authored at
# the root is continued from the subdir as long as the slug recipe sees the
# same root. git init is real, because rev-parse must answer.
git -C "$work/gitproj" init -q 2>/dev/null
root_chat "$work/gitproj" root
chk "claude from a subdirectory continues it" "claude [--continue]" \
    "$(cd "$work/gitproj" && run '(cd src && claude)')"
rm -rf "$(slug_points_at "$work/gitproj")"

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
