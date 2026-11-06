#!/usr/bin/env bash
# Prints the rules files that apply to one path, or to one shell command with
# --command, one per line.
#
# Rules live in ../../rules/*.md and declare their own trigger in frontmatter, so
# adding one is a new file and never a code change:
#
#   ---
#   when: "*.rs *.rs.in"
#   commands: "cargo rustc"
#   ---
#
# `when` is a space-separated list of shell globs matched against the whole path.
# `*` spans slashes in a case pattern, so `*.rs` already means "any path ending
# .rs" at any depth and there is no need for a `**` form — which would be worse
# than useless here, since `**/*.rs` in a case pattern requires a slash and so
# would miss a crate root's main.rs.
#
# `commands` is an optional space-separated list of program names, matched against
# every word of a shell command, by its last path component and after any `(`,
# backtick, `$`, `;`, `&`, `|` or quote glued to its front: `/usr/bin/nix`, `$(nix`,
# `x;nix` and the `'nix` of `sh -c 'nix build'` all run nix.
#
# Independent of every skill. A rule fires because a file was written or read, or a
# program ran, not because something was loaded. That is the whole point: guidance
# that applies in an implementation session or a one-line fix alike.
#
# AGENT_RULES_DIR replaces ../../rules, so tests can run against fixture rules instead
# of whatever guidance happens to be installed.
#
# Exit is always 0. A rule that cannot be read is not a reason to fail a tool call
# that already succeeded.

set -uo pipefail

key=when

if [ "${1:-}" = --command ]; then
    key=commands
    shift
fi

subject=${1:-}
[ -n "$subject" ] || exit 0

if [ "$key" = commands ]; then
    # Split with read, which runs no pathname expansion, and to NUL so a
    # multi-line command contributes every line.
    read -r -d '' -a words <<<"$subject"
fi

dir=$(cd "${AGENT_RULES_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../rules}" 2>/dev/null && pwd) || exit 0
separators="[(\`\$;&|\"']"

for f in "$dir"/*.md; do
    [ -f "$f" ] || continue

    # First match only, and only in the frontmatter: a key in the body is prose,
    # not configuration. A formatter wraps a long value onto the indented lines
    # below the key; they belong to the value up to the first line that is not
    # indented.
    value=$(awk -v key="$key:" '
        NR == 1 && $0 == "---" { next }
        $0 == "---" { exit }
        found && /^[[:space:]]/ { value = value " " $0; next }
        found { exit }
        $0 == key || (index($0, key) == 1 && substr($0, length(key) + 1, 1) ~ /[[:space:]]/) {
            value = substr($0, length(key) + 1)
            found = 1
        }
        END { if (found) print value }
    ' "$f" 2>/dev/null)
    [ -n "$value" ] || continue
    value=${value//\"/}
    value=${value//\'/}

    # Split with read, not with an unquoted $value: that also ran pathname expansion
    # against the working directory, which is the session's project root. A crate
    # with build.rs at its root turned `*.rs` into `build.rs`, and the rule never
    # fired for anything under src/. Each glob has to reach `case` as a glob.
    read -r -a items <<<"$value"

    if [ "$key" = commands ]; then
        for word in "${words[@]}"; do
            # Unquoted on purpose: the separators are a bracket pattern.
            # shellcheck disable=SC2295
            word=${word##*$separators}

            for program in "${items[@]}"; do
                if [ "${word##*/}" = "$program" ]; then
                    printf '%s\n' "$f"
                    continue 3
                fi
            done
        done

        continue
    fi

    for glob in "${items[@]}"; do
        # Unquoted on purpose: quoted, `case` would match the glob literally.
        # shellcheck disable=SC2254
        case $subject in
            $glob)
                printf '%s\n' "$f"
                break
                ;;
        esac
    done
done
