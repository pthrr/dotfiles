#!/usr/bin/env bash
# Stateless policy for the shared approval protocol. adapter.ts owns one proposal
# per session, its unique version, presentation and approval. This script checks
# plan format, direct file scope, exact consent, and full presentation at Stop.
#
# PLAN.md and known file targets in the whitelist are free. Read-only shell calls
# are filtered by shell-policy.ts. Every other shell call requires the approved
# proposal and exact human "ok", regardless of its working directory.
#
# Ordinary turn endings preserve the batch. Deleting PLAN.md closes it; the
# adapter observes deletion and identity changes before accepting another write.
# Exit 2 blocks the operation; stderr explains the rejection.

set -uo pipefail

mode=${1:-}
input=$(cat)

field() { printf '%s' "$input" | jq -r "$1"; }

cwd=$(field '.cwd // empty')
[ -n "$cwd" ] || cwd=$PWD

# Every path the gate compares is absolute and resolved, symlinks included, the
# way adapter.ts canonicalizes: a plan path recorded at one hook then matches the
# same plan at the next, and a write through a link is judged where it lands.
absolute() {
    case $1 in
        /*) realpath -m -- "$1" ;;
        *) realpath -m -- "$cwd/$1" ;;
    esac
}

home=$(realpath -m -- "${HOME:-/nonexistent}")
tmp=$(realpath -m -- "${TMPDIR:-/tmp}")

# Harness config, memory and state, plus /tmp and $HOME/tmp, are exempt.
# The caller supplies actual file targets. Shell calls never use this exemption:
# their working directory does not establish where they can write.
#
# Whole directories, not the state paths inside them. `*` spans slashes in a case
# pattern, so one entry per tree covers everything beneath it. The adapter checks
# the actual target of each file operation, including rename endpoints.
#
# A dotfile directly in $HOME is not covered and cannot be: the gate keys on the
# containing directory, so reaching those means whitelisting $HOME, which would
# ungate every non-repo tree under it. Home Manager's links are read-only; edit
# their sources in the dotfiles repo.
harness_owned() {
    case $1 in
        "$home"/.claude | "$home"/.claude/* | \
        "$home"/.codex | "$home"/.codex/* | \
        "$home"/.agents | "$home"/.agents/* | \
        "$home"/.config/opencode | "$home"/.config/opencode/* | \
        "$home"/.local/share/opencode | "$home"/.local/share/opencode/* | \
        /tmp | /tmp/* | \
        "$home"/tmp | "$home"/tmp/*) return 0 ;;
    esac
    return 1
}

# The directory of the nearest non-empty PLAN.md at or above a directory.
#
# Walking up is what makes a plan work in a subdirectory: a write to src/lib.rs
# belongs to the project whose root holds PLAN.md, not to wherever the session
# happens to be rooted. The walk stops at a repo boundary so a stray PLAN.md in
# a parent repo can never cover an unrelated checkout below it.
#
# A stale PLAN.md in /tmp covered every sandbox under the temp tree the same way:
# no repo boundary sits between /tmp and the sandboxes beneath it, so the walk
# kept climbing and read one. $HOME, the temp tree and / are containers and
# harness scratch, never projects — the walk stops when it reaches one, before
# reading the plan of its own: the container must not govern the projects and
# scratch below it, and scratch above the temp boundary is none of the walk's
# business. Repo-root and project plans live below those containers and are
# still read on the way.
#
# statusline.sh repeats this walk for its badge; keep the two in step.
find_plan() {
    local d=$1
    while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
        # /tmp is pinned alongside $tmp: a session may run with a private temp
        # (nix shells), but /tmp itself is scratch whatever the session mounts
        # its temp at, so the walk must stop there regardless.
        [ "$d" = "$home" ] && return 1
        [ "$d" = "$tmp" ] && return 1
        [ "$d" = "/tmp" ] && return 1
        if [ -s "$d/PLAN.md" ]; then
            printf '%s\n' "$d"
            return 0
        fi
        [ -e "$d/.git" ] && return 1
        d=$(dirname "$d")
    done
    return 1
}

# The plan format. Each section has to say something, and each Changes bullet has
# to name a file and say what happens to it, so a token plan fails here rather
# than reaching the user as something to approve:
#
#   # <title>
#   ## Problem
#   <what is wrong or wanted, and why>
#   ## Changes
#   - `path/to/file` — <what changes, current -> future, why>
#   - `path/to/dir/` — <the same, for everything under the directory>
#   ## Verify
#   <commands or checks that prove it works>
#
# Paths are relative to the directory holding PLAN.md, or absolute. Lines inside
# a fenced block are body text, never headings: a `# comment` in a shell snippet
# must not end the section it sits in.
min_words=5
plan_awk='
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function check(b,   head, rest, words) {
        if (!match(b, /^[-*][ \t]+`[^`]+`/)) {
            print "a ## Changes bullet does not start with a `path`: " substr(b, 1, 60)
            return
        }
        head = substr(b, RSTART, RLENGTH)
        rest = substr(b, RSTART + RLENGTH)
        sub(/^[ \t]*(—|–|-|:)?[ \t]*/, "", rest)
        if (split(rest, words, /[ \t]+/) < min)
            print "the ## Changes bullet " trim(substr(head, 2)) " says too little: name what changes, from what to what, and why"
    }
    function flush() { if (bullet != "" && want == "problems") check(bullet); bullet = "" }
    /^[ \t]*(```|~~~)/ { fence = !fence; flush(); if (section != "") body[section]++; next }
    fence { if (section != "") body[section]++; next }
    /^##[ \t]/ { flush(); section = tolower(trim(substr($0, 3))); seen[section] = 1; next }
    /^#([ \t]|$)/ { flush(); section = ""; next }
    section == "changes" && /^[-*][ \t]/ {
        flush()
        bullet = $0
        bullets++
        body[section]++
        if (want == "paths" && match($0, /^[-*][ \t]+`[^`]+`/)) {
            path = substr($0, RSTART, RLENGTH)
            sub(/^[-*][ \t]+`/, "", path)
            sub(/`$/, "", path)
            print path
        }
        next
    }
    section == "changes" && bullet != "" && /^[ \t]+[^ \t]/ { bullet = bullet " " trim($0); next }
    /[^ \t]/ { flush(); if (section != "") body[section]++ }
    END {
        if (want != "problems") exit
        flush()
        split("Problem Changes Verify", required, " ")
        for (i = 1; i <= 3; i++) {
            s = tolower(required[i])
            if (!(s in seen)) print "no ## " required[i] " section"
            else if (!(s in body)) print "the ## " required[i] " section is empty"
        }
        if (("changes" in seen) && !bullets) print "## Changes lists no files"
    }
'
# The paths its Changes bullets name, one per line, as written.
listed_paths() { awk -v want=paths -v min="$min_words" "$plan_awk" "$1"; }

# One line per thing wrong with a plan; nothing when it is well-formed.
#
# Entries are checked against the plan's own directory too. `./` lists the whole
# tree, which names nothing; an entry outside the tree can never be covered,
# because a write there finds its own plan, or none, on the way up.
plan_problems() {
    local plan=$1 dir entry resolved
    dir=$(dirname "$plan")
    awk -v want=problems -v min="$min_words" "$plan_awk" "$plan"
    while IFS= read -r entry; do
        [ -n "$entry" ] || continue

        case $entry in /*) resolved=$(absolute "$entry") ;; *) resolved=$(absolute "$dir/$entry") ;; esac
        if [ "$resolved" = "$dir" ]; then
            echo "the ## Changes entry \`$entry\` is the whole tree; name the files or subdirectories that change"
        elif [[ $resolved != "$dir"/* ]]; then
            echo "the ## Changes entry \`$entry\` is outside $dir, so this plan can never cover it"
        fi
    done < <(listed_paths "$plan")
}

# No `--`: bazelisk ships a sha256sum that shadows coreutils on PATH, accepts
# exactly one file and prints only the hash. Paths here are always absolute, so
# none can be read as an option, and cut takes the hash from either output.
hash_of() { sha256sum "$1" | cut -d' ' -f1; }

# Whitespace collapsed, so a plan pasted into a reply still matches after the
# reply rewraps or re-indents it. Anything else must be verbatim.
normalized() { tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//'; }

case "$mode" in
pre-write)
    tool=$(field '.tool_name // empty')
    file=$(field '.tool_input.file_path // empty')

    if [ "$tool" != "Bash" ]; then
        if [ -z "$file" ]; then
            echo "write-gate: no file path to check; write denied." >&2
            exit 2
        fi

        target=$(absolute "$file")
        target_dir=$(dirname "$target")

        if [ "${target##*/}" = "PLAN.md" ]; then
            jq -cn --arg p "$target" '{plan_written: $p}'
            exit 0
        fi

        harness_owned "$target_dir" && exit 0
    fi

    # Compare JSON strings directly: shell command substitution would strip a
    # trailing newline and accidentally turn "ok\n" into approval.
    if [ "$(field '.prompt == "ok"')" != true ]; then
        echo 'write-gate: this change is not authorized; the latest human message must be exactly "ok".' >&2
        exit 2
    fi

    plan=$(field '.proposal.path // empty')

    if [ -z "$plan" ] || [ "$(field '.proposal.shown == true and .proposal.approved == true')" != true ]; then
        echo "write-gate: no approved proposal; show one PLAN.md in full and wait for a new exact ok." >&2
        exit 2
    fi

    if [ ! -s "$plan" ] || [ "$(hash_of "$plan")" != "$(field '.proposal.hash // empty')" ]; then
        echo "write-gate: the approved PLAN.md was deleted or changed; present the current version and wait for a new ok." >&2
        exit 2
    fi

    problems=$(plan_problems "$plan")

    if [ -n "$problems" ]; then
        echo "write-gate: $plan is not a usable plan:" >&2
        printf '%s\n' "$problems" | sed 's/^/  - /' >&2
        exit 2
    fi

    # Shell effects are not inferred from cwd. A shell call uses the session's
    # approved proposal even when it runs in /tmp or a different directory.
    if [ "$tool" = "Bash" ]; then
        jq -cn --arg p "$plan" '{governed_by: $p}'
        exit 0
    fi

    if ! plan_dir=$(find_plan "$target_dir"); then
        echo "write-gate: no PLAN.md at or above $target_dir." >&2
        exit 2
    fi

    if [ "$plan_dir/PLAN.md" != "$plan" ]; then
        echo "write-gate: $target belongs to a different proposal; present that plan and wait for its ok." >&2
        exit 2
    fi

    listed=false

    while IFS= read -r entry; do
        [ -n "$entry" ] || continue

        case $entry in /*) path=$entry ;; *) path=$plan_dir/$entry ;; esac

        resolved=$(absolute "$path")

        case $entry in
            */) case $target in "$resolved"/*) listed=true ;; esac ;;
            *) [ "$resolved" = "$target" ] && listed=true ;;
        esac
    done < <(listed_paths "$plan")

    if [ "$listed" != true ]; then
        echo "write-gate: $target is not listed under ## Changes in $plan." >&2
        echo "Revise the plan, show it in full, and wait for a new ok." >&2
        exit 2
    fi

    jq -cn --arg p "$plan" '{governed_by: $p}'
    ;;

stop)
    message=$(field '.last_assistant_message // empty')
    has_message=$(field '.last_assistant_message | type == "string"')
    shown_text=$(normalized <<<"$message")

    shows() {
        local text
        [ "$has_message" = true ] || return 1
        text=$(normalized <"$1")
        [ -n "$text" ] && [[ $shown_text == *"$text"* ]]
    }

    mapfile -t written < <(field '.plans_written[]? // empty')
    current=$(field '.proposal.path // empty')
    cwd_plan=""

    if directory=$(find_plan "$(absolute "$cwd")"); then
        cwd_plan=$directory/PLAN.md
    fi

    presented=()
    problems=()

    while IFS= read -r plan; do
        [ -n "$plan" ] && [ -s "$plan" ] || continue

        if shows "$plan" && [ -z "$(plan_problems "$plan")" ]; then
            presented+=("$plan")
        fi
    done < <(printf '%s\n' "${written[@]}" "$current" "$cwd_plan" | sort -u)

    if [ ${#presented[@]} -gt 1 ]; then
        echo '{"ambiguous":true}'
        [ "$(field '.stop_hook_active // false')" = true ] && exit 0
        echo "write-gate: show exactly one proposal; a single ok cannot select between multiple plans." >&2
        exit 2
    fi

    for plan in "${presented[@]}"; do
        jq -cn --arg p "$plan" --arg h "$(hash_of "$plan")" '{presented: $p, hash: $h}'
    done

    # A retry still records a presentation, but cannot create an endless hold.
    [ "$(field '.stop_hook_active // false')" = true ] && exit 0

    for plan in "${written[@]}"; do
        [ -e "$plan" ] || continue

        while IFS= read -r problem; do
            [ -n "$problem" ] && problems+=("$plan: $problem")
        done < <(plan_problems "$plan")

        if [ "$has_message" = true ] && ! shows "$plan"; then
            problems+=("$plan was written this turn, but the final message does not show it in full")
        fi
    done

    [ ${#problems[@]} -eq 0 ] && exit 0
    echo "write-gate: present the proposal before ending this turn:" >&2
    printf '  - %s\n' "${problems[@]}" >&2
    echo "Show the current PLAN.md in full and wait for an exact ok." >&2
    exit 2
    ;;

*)
    echo "write-gate: unknown mode '${mode}' (pre-write or stop)" >&2
    exit 1
    ;;
esac
