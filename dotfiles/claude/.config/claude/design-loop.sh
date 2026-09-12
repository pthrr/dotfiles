#!/usr/bin/env bash
# Two enforcement layers, keyed off different signals.
#
#   pre-write  PreToolUse on Write|Edit — no code write without PLAN.md.
#              PLAN.md is a general "problem is settled" gate; every project
#              can and should have one.
#   stop       Stop — no turn ends without the fixed ITERATION render, but
#              only once the software-design skill has been invoked in this
#              session's transcript. Without that, the general PLAN.md case
#              stays unrestricted at turn end.
#   activate   SessionStart — on resume/compact, if the prior transcript
#              shows the software-design skill was loaded, re-inject the
#              loop's rules so they survive the compaction. Noop on fresh
#              startup or when no PLAN.md is around: the skill itself carries
#              the rules when the model loads it inside a live session.
#
# The switches:
#
#   no PLAN.md, or an  -> every Write/Edit is denied except PLAN.md itself, so
#   empty one             step 0 (settle the problem WITH THE USER) must happen
#                         before any code exists. Turn ends are unrestricted.
#   PLAN.md with        -> writes are allowed. If a Skill tool_use for
#   content in cwd         software-design appears in the transcript, every
#                          turn must end with the fixed render; otherwise turn
#                          ends are unrestricted.
#
# The strict switch is a tool_use record in the transcript, not a file the
# model can create or delete. It flips on when the model actually loads the
# skill and flips off with a fresh session.
#
# This stops a model that drifts. It is not proof against one actively working
# around it — a model can decline to load the skill and never enter strict
# mode. Drift is the actual failure mode.
#
# Exit 2 is the blocking code: stderr goes back to the model as the reason.

set -uo pipefail

mode=${1:-}
input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd=$PWD

# Whether the software-design skill has been invoked in a transcript.
# Prints "true" or "false". A missing or unreadable transcript is "false".
skill_loaded() {
    local transcript=$1
    [ -f "$transcript" ] || { echo false; return; }
    jq -rs '
        [ .[]
          | select(.type == "assistant")
          | (.message.content // [])[]?
          | select(.type == "tool_use" and .name == "Skill")
          | .input.skill // empty
        ] | any(. == "software-design")
    ' "$transcript" 2>/dev/null || echo false
}

# The nearest non-empty PLAN.md at or above a directory, or nothing.
#
# Walking up is what makes a loop work in a subdirectory: a write to src/lib.rs
# belongs to the project whose root holds PLAN.md, not to wherever the session
# happens to be rooted. The walk stops at a repo boundary so a stray PLAN.md in
# a parent repo can never arm a loop in an unrelated checkout below it.
find_plan() {
    local d=$1
    while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
        if [ -s "$d/PLAN.md" ]; then
            printf '%s\n' "$d"
            return 0
        fi
        [ -e "$d/.git" ] && return 1
        d=$(dirname "$d")
    done
    return 1
}

case "$mode" in
pre-write)
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

    # The write that creates PLAN.md cannot be gated on PLAN.md existing.
    [ "${file##*/}" = "PLAN.md" ] && exit 0

    # Search from the file being written, not from the session root: a write into
    # a subdirectory is governed by its own project's PLAN.md.
    target_dir=$(dirname "$file")
    [ -d "$target_dir" ] || target_dir=$cwd
    find_plan "$target_dir" >/dev/null && exit 0

    echo "design-loop: no non-empty PLAN.md at or above $target_dir." >&2
    echo "Step 0 of the software-design skill runs first: settle the problem statement" >&2
    echo "WITH THE USER — ask, do not assume — and write it to PLAN.md. Code comes after." >&2
    exit 2
    ;;

stop)
    proj=$(find_plan "$cwd") || exit 0

    # Set on a turn this hook already blocked; re-blocking would loop forever.
    [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

    transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
    [ -f "$transcript" ] || exit 0

    # Strict render enforcement runs only when the software-design skill has
    # been invoked in this transcript. PLAN.md by itself means "the problem is
    # settled before writing code" — it does not imply the design ladder is
    # running. Turn ends stay unrestricted for the general PLAN.md case.
    [ "$(skill_loaded "$transcript")" = "true" ] || exit 0

    last=$(jq -rs '
        [ .[] | select(.type == "assistant") ] | last
        | (.message.content // [])
        | map(select(.type == "text") | .text)
        | join("\n")
    ' "$transcript" 2>/dev/null) || exit 0

    missing=()
    for marker in 'ITERATION ' '1 CODE ORGA' '2 PRIMITIVES' '3 INTERACTION' 'DELTA' 'OPEN'; do
        printf '%s\n' "$last" | grep -q "^${marker}" || missing+=("$marker")
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo "design-loop: the iteration render is missing or malformed (no ${missing[*]})." >&2
        echo "End the iteration with the fixed block from the software-design skill — same shape" >&2
        echo "every time, no additions, no prose after it — then stop and wait for the user's OK." >&2
        exit 2
    fi

    # Rows cite file:line. Every citation must resolve, or the render was
    # composed from intent rather than read off disk.
    bad=()
    while read -r ref; do
        [ -n "$ref" ] || continue
        path=${ref%:*}
        line=${ref##*:}

        target=""
        [ -f "$cwd/$path" ] && target="$cwd/$path"
        [ -z "$target" ] && [ -f "$path" ] && target="$path"
        if [ -z "$target" ]; then
            bad+=("$ref (no such file)")
            continue
        fi

        count=$(wc -l <"$target")
        # +1 tolerates a final line with no trailing newline.
        [ "$line" -le $((count + 1)) ] || bad+=("$ref (file ends at line $count)")
    done < <(printf '%s\n' "$last" | grep -oE '[A-Za-z0-9_./-]+\.[A-Za-z0-9]+:[0-9]+' | sort -u)

    if [ ${#bad[@]} -ne 0 ]; then
        echo "design-loop: the render cites locations that do not exist:" >&2
        printf '  %s\n' "${bad[@]}" >&2
        echo "Rows are read off the files on disk, never composed from intent. Write the" >&2
        echo "declaration first, then cite where it actually landed." >&2
        exit 2
    fi

    # A `ceiling:` in OPEN claims a deliberate simplification is marked at the
    # decision. Claiming it and not writing the marker is how the ledger rots.
    printf '%s\n' "$last" | grep -q 'ceiling:' || exit 0
    grep -rqE '(#|//|--|;) ?design:' "$proj" \
        --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=target \
        --exclude-dir=.venv --exclude=PLAN.md 2>/dev/null && exit 0

    echo "design-loop: OPEN claims a ceiling: but no design: marker exists under $proj." >&2
    echo "A ceiling is recorded at the decision, not only in the render — the render" >&2
    echo "scrolls away. Add a comment naming the ceiling AND the upgrade path, e.g." >&2
    echo "  // design: single-threaded over disjoint ranges, split per range if build latency matters" >&2
    exit 2
    ;;

activate)
    # SessionStart. Re-inject the ladder only when a compaction or resume is
    # picking up a session that was already in strict mode; a fresh startup
    # has no prior transcript to key off, and if the user wants strict mode
    # they will load the skill, whose own text carries the ladder.
    proj=$(find_plan "$cwd") || exit 0

    source=$(printf '%s' "$input" | jq -r '.source // empty')
    case "$source" in
        resume|compact) ;;
        *) exit 0 ;;
    esac

    transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
    [ "$(skill_loaded "$transcript")" = "true" ] || exit 0

    # The whole paragraph under "Done when", not its first line: a one-sentence
    # goal still wraps, and half a sentence is worse than none.
    goal=$(awk '
        /^#+[[:space:]]*[Dd]one [Ww]hen/ { in_section = 1; next }
        in_section && /^#/             { exit }
        in_section && /^[[:space:]]*$/ { if (got) exit; next }
        in_section                     { printf "%s ", $0; got = 1 }
    ' "$proj/PLAN.md" 2>/dev/null | sed 's/[[:space:]]*$//')
    [ -n "$goal" ] || goal="(no 'Done when' section found in PLAN.md)"

    jq -n --arg goal "$goal" '{
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: (
          "A software-design loop is running in this directory: PLAN.md exists and holds the approved problem statement.\n\n" +
          "GOAL: " + $goal + "\n\n" +
          "Binding rules for every turn here, enforced by hooks, not by your judgement:\n" +
          "- The architecture lives in the source tree. No DESIGN.md, no architecture prose, no sketch that becomes code later. Bodies may be todo!(); declarations may not.\n" +
          "- One pass covers three axes in order: 1 code organization, 2 primitives as concrete symbols with their invariant as a doc comment above each declaration, 3 how those symbols interact at runtime (threads, ownership across them, handover, sync/async, backpressure).\n" +
          "- Every turn ends with the ITERATION render and nothing after it:\n" +
          "  ITERATION <n> / GOAL / 1 CODE ORGA / 2 PRIMITIVES / 3 INTERACTION / DELTA / OPEN\n" +
          "  Rows are read off the files on disk. A file:line that does not resolve is a fabricated row and the turn will be rejected.\n" +
          "- The loop does not self-terminate. Only the user OK ends it. Do not ask whether to continue; render and stop.\n" +
          "- A deliberate simplification with a known ceiling gets a `design:` comment at the decision naming the ceiling and the upgrade path.\n\n" +
          "Read the software-design skill for the full ladder before cutting symbols."
        )
      }
    }'
    exit 0
    ;;

*)
    echo "design-loop: unknown mode '${mode}'" >&2
    exit 1
    ;;
esac
