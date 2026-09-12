#!/usr/bin/env bash
# Prints the rules files that apply to one written path, one per line.
#
# Rules live in ../rules/*.md and declare their own trigger in frontmatter, so
# adding one is a new file and never a code change:
#
#   ---
#   when: "*.rs *.rs.in"
#   ---
#
# `when` is a space-separated list of shell globs matched against the whole path.
# `*` spans slashes in a case pattern, so `*.rs` already means "any path ending
# .rs" at any depth and there is no need for a `**` form — which would be worse
# than useless here, since `**/*.rs` in a case pattern requires a slash and so
# would miss a crate root's main.rs.
#
# Independent of every skill. Nothing here reads the design loop's state, and a
# rule fires because a file was written, not because something was loaded. That is
# the whole point: guidance that applies in an implementation session, a one-line
# fix, or a session that has never heard of the design loop.
#
# Exit is always 0. A rule that cannot be read is not a reason to fail a tool call
# that already succeeded.

set -uo pipefail

path=${1:-}
[ -n "$path" ] || exit 0

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../rules" 2>/dev/null && pwd) || exit 0

for f in "$dir"/*.md; do
    [ -f "$f" ] || continue

    # First match only: a second `when:` in the body is prose, not configuration.
    when=$(grep -m1 '^when:[[:space:]]' "$f" 2>/dev/null) || continue
    when=${when#when:}
    when=${when//\"/}
    when=${when//\'/}

    # Unquoted on purpose — word splitting gives the list, and the glob has to stay
    # a glob for `case` to match it as one.
    for glob in $when; do
        # shellcheck disable=SC2254
        case $path in
            $glob)
                printf '%s\n' "$f"
                break
                ;;
        esac
    done
done
