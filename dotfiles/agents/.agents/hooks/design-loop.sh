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
#   empty one             the problem loop (settle it WITH THE USER) must happen
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

# PLAN.md markers, both hand-written and never by the model.
#
#   ## Closed     design accepted -> implement freely, no render owed
#   ## Finished   problem shipped -> writes denied again, so the NEXT task
#                 cannot inherit this one's closure
#
# `## Finished` exists because `## Closed` is permanent: once a subtree said
# "implement freely" it kept saying it for every later, unrelated request, and
# the design loop never re-armed. Finished sends the directory back to step 0.
# It wins over Closed when both are present — a plan goes Closed -> Finished
# and never back — and is reversed by deleting the line, which is the escape
# hatch for work the old plan really does cover.
#
# Leading space is capped at 3, not `[[:space:]]*`: CommonMark reads 0-3 spaces
# as a heading and 4+ as a code block, so an unbounded prefix let a PLAN.md that
# merely *quotes* a marker as an indented example trip it.
#
# `finished` takes a trailing note like `closed` does. `done` deliberately does
# not appear here: `^ *## *done( .*)?$` also matches `## Done when`, the core
# field every plan carries, which would mark every plan ever written as done.
plan_closed() {
    grep -qiE '^ {0,3}##[[:space:]]+closed([[:space:]].*)?$' "$1/PLAN.md" 2>/dev/null
}
plan_finished() {
    grep -qiE '^ {0,3}##[[:space:]]+finished([[:space:]].*)?$' "$1/PLAN.md" 2>/dev/null
}

# The paragraph under `## Done when`, for quoting back at the model. Without the
# goal a denial is just "no", and the model has no way to judge whether the
# request it was asked for is covered by the plan already sitting there.
plan_goal() {
    awk '
        tolower($0) ~ /^#+[[:space:]]*done when[[:space:]]*:?[[:space:]]*$/ { s = 1; next }
        s && /^#/             { exit }
        s && /^[[:space:]]*$/ { if (got) exit; next }
        s                     { printf "%s ", $0; got = 1 }
    ' "$1/PLAN.md" 2>/dev/null | sed 's/[[:space:]]*$//'
}

case "$mode" in
pre-write)
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

    # The write that creates PLAN.md cannot be gated on PLAN.md existing.
    [ "${file##*/}" = "PLAN.md" ] && exit 0

    # Search from the file being written, not from the session root: a write into
    # a subdirectory is governed by its own project's PLAN.md.
    #
    # The directory need not exist yet. The first write into a new subtree
    # (src/, migrations/) is the write that creates it, and find_plan walks up
    # through the components that do exist. Falling back to $cwd when the leaf
    # was missing pointed the gate at whichever project the session happened to
    # be sitting in, and denied the write citing an unrelated PLAN.md. The repo
    # boundary still holds: the walk stops at the first .git it meets.
    target_dir=$(dirname "$file")
    case "$target_dir" in /*) ;; *) target_dir=$cwd/$target_dir ;; esac

    if proj=$(find_plan "$target_dir"); then
        plan_finished "$proj" || exit 0

        # A finished plan denies like no plan at all, but for the opposite
        # reason — not "nothing was ever settled" but "what was settled here
        # already shipped" — so the message has to carry the old goal. Without
        # it the model cannot tell a follow-up from a genuinely new problem.
        goal=$(plan_goal "$proj")
        echo "design-loop: PLAN.md at $proj is marked ## Finished." >&2
        [ -n "$goal" ] && echo "Its goal was: $goal" >&2
        echo "If this request is covered by that goal, delete the ## Finished line." >&2
        echo "If it is a new problem, run the problem loop of the software-design skill —" >&2
        echo "settle it WITH THE USER, ask, do not assume — and rewrite PLAN.md. Code after." >&2
        exit 2
    fi

    echo "design-loop: no non-empty PLAN.md at or above $target_dir." >&2
    echo "The problem loop of the software-design skill runs first: settle the problem" >&2
    echo "statement WITH THE USER — ask, do not assume — and write it to PLAN.md." >&2
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

    # The loop is over once the user accepts the design. PLAN.md is tri-state,
    # because one file has to answer two questions with different lifetimes:
    #
    #   absent or empty   writes denied, turn ends free   (settle the problem)
    #   present           writes allowed, render required (loop running)
    #   present + marker  writes allowed, turn ends free  (implementation)
    #
    # Emptying PLAN.md cannot be the done-signal: pre-write tests -s, so an
    # empty file denies every write instead of releasing implementation.
    #
    # The marker is written by hand, never by the model. skill_loaded flips on
    # from a tool_use the model emits, so keying the exit off a second skill
    # invocation would let it disarm the guard by loading one. Ending the loop
    # stays the user's move, so the marker is a heading short enough to type
    # from memory — `## Closed` — in the same `## <Field>` vocabulary the rest
    # of PLAN.md already uses. Anchored at both ends: a trailing note like
    # `## Closed 2026-09-20` still releases, `## Closing thoughts` does not.
    #
    # Leading space is capped at 3, not `[[:space:]]*`: CommonMark reads 0-3
    # spaces as a heading and 4+ as a code block, and an unbounded prefix let a
    # PLAN.md that merely *quotes* the marker as an indented example release the
    # loop — the plan disarming the loop by documenting how to disarm it.
    # Closure composes: the tree is closed only when every PLAN.md in it is.
    # Resolution is gitignore-shaped — the nearest PLAN.md above a path governs
    # it, and a nested one shadows its parent — but that decides *which* plan
    # owns a path and whose DONE WHEN the GOAL quotes, not whether a render is
    # owed. An open plan anywhere means a design problem is in progress, and the
    # loop is active every response while it is.
    #
    # Checking only $proj let a closed root mask an open subtree: the render was
    # owed from a session rooted in that subtree and silently not owed from the
    # repo root, which is where most work actually happens.
    # Scope is what the turn wrote, not the whole tree. Arming on any open plan
    # anywhere made unrelated repo work — a pre-commit hook, a .gitignore — owe a
    # render for a design loop it never touched.
    #
    # Read from the transcript this hook already parses, so nothing is carried
    # between invocations. A PLAN.md resolves to its own directory, so loop 1
    # still renders even though it writes nothing else.
    touched=$(jq -rs '
        (map(.type == "user") | rindex(true)) as $u
        | .[(($u // -1) + 1):]
        | map(select(.type == "assistant")
              | (.message.content // [])[]?
              | select(.type == "tool_use"
                       and (.name == "Write" or .name == "Edit" or .name == "NotebookEdit"))
              | .input.file_path // empty)
        | .[]
    ' "$transcript" 2>/dev/null)
    [ -n "$touched" ] || exit 0

    armed=false
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        plan=$(find_plan "$(dirname "$path")") || continue
        # Finished frees turn ends exactly as Closed does — the render is owed
        # only while a design is in progress, and neither state is one.
        plan_closed "$plan" || plan_finished "$plan" || armed=true
    done <<TOUCHED
$touched
TOUCHED
    [ "$armed" = true ] || exit 0

    # Every assistant text record since the last user turn, joined.
    #
    # Not "the last assistant record": one turn is written as several records
    # split by content type — thinking, tool_use, text — so the last record is
    # routinely a thinking or tool_use one carrying no text at all, and pulling
    # text off it yields "". An empty string then reports as all six markers
    # missing, which is how a well-formed render gets rejected.
    last=$(jq -rs '
        (map(.type == "user") | rindex(true)) as $u
        | .[(($u // -1) + 1):]
        | map(select(.type == "assistant")
              | (.message.content // [])
              | select(any(.[]?; .type == "text"))
              | map(select(.type == "text") | .text)
              | join("\n"))
        | if length == 0 then null else join("\n") end
    ' "$transcript" 2>/dev/null) || exit 0

    # No text record for this turn is on disk yet. Stop fires before the final
    # record is always flushed, so this means the turn is unreadable, not that
    # it was malformed — blocking here rejects renders that were emitted. A
    # turn that really did emit text lands below, empty string included.
    [ "$last" = "null" ] && exit 0

    # Two block shapes are valid, one per loop: PROBLEM while the problem is
    # still being settled, ITERATION once PLAN.md exists and symbols are being
    # cut. Accepting only ITERATION was safe while a loop could not start under
    # an already-open plan — loop 1 ran with no PLAN.md at all, so this branch
    # was never reached. With closure composing across the tree it is reachable,
    # and a correct PROBLEM pass would be rejected for missing axis headings.
    iteration_missing=()
    for marker in 'ITERATION ' '1 CODE ORGA' '2 PRIMITIVES' '3 INTERACTION' 'DELTA' 'OPEN'; do
        printf '%s\n' "$last" | grep -q "^${marker}" || iteration_missing+=("$marker")
    done

    problem_missing=()
    for marker in 'PROBLEM ' 'DONE WHEN' 'IN / OUT' 'BUDGETS' 'FAILURES' 'NON-GOALS' 'STACK' 'EXISTING' 'UNKNOWNS'; do
        printf '%s\n' "$last" | grep -q "^${marker}" || problem_missing+=("$marker")
    done

    if [ ${#iteration_missing[@]} -eq 0 ]; then
        shape=iteration
    elif [ ${#problem_missing[@]} -eq 0 ]; then
        shape=problem
    else
        echo "design-loop: no well-formed render (ITERATION missing ${iteration_missing[*]};" >&2
        echo "PROBLEM missing ${problem_missing[*]})." >&2
        echo "End the turn with the fixed block from the software-design skill — same shape" >&2
        echo "every time, no additions, no prose after it — then stop and wait for the user's OK." >&2
        exit 2
    fi

    # Citations are an axis-2 rule, so only an ITERATION render is held to them.
    # A PROBLEM block cites evidence in prose — a line range, a bare filename —
    # which is not a row read off disk and must not be checked as one.
    [ "$shape" = "iteration" ] || exit 0

    # Rows cite file:line. Every citation must resolve, or the render was
    # composed from intent rather than read off disk.
    #
    # Axis 2 is clustered: the path is written once on a cluster header and each
    # row under it cites a bare `:<line>`. Those are expanded against the nearest
    # header above them so they get checked like any other citation. A `:<line>`
    # with no header above it expands to a sentinel that fails resolution —
    # otherwise the shortened form would be a hole where a row cites nothing and
    # passes. Scoped to axis 2 so a path in `1 CODE ORGA` cannot supply a header
    # for rows that never had one.
    expand_clusters() {
        awk '
            /^2 PRIMITIVES/  { inp = 1; next }
            /^3 INTERACTION/ { inp = 0 }
            !inp { next }
            $1 ~ /^[A-Za-z0-9_.\/-]+\.[A-Za-z0-9]+$/ { path = $1; next }
            $1 ~ /^:[0-9]+$/ { print (path == "" ? "<no-cluster-header>" : path) $1 }
        '
    }

    bad=()
    while read -r ref; do
        [ -n "$ref" ] || continue
        path=${ref%:*}
        line=${ref##*:}

        if [ "$path" = "<no-cluster-header>" ]; then
            bad+=(":$line (a row with no cluster header above it)")
            continue
        fi

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
    done < <(
        {
            printf '%s\n' "$last" | grep -oE '[A-Za-z0-9_./-]+\.[A-Za-z0-9]+:[0-9]+'
            printf '%s\n' "$last" | expand_clusters
        } | sort -u
    )

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
        startup|resume|compact) ;;
        *) exit 0 ;;
    esac

    # The whole paragraph under a heading, not its first line: a one-sentence
    # goal still wraps, and half a sentence is worse than none.
    section() {
        awk -v want="$1" '
            tolower($0) ~ "^#+[[:space:]]*" want "[[:space:]]*:?[[:space:]]*$" { in_section = 1; next }
            in_section && /^#/             { exit }
            in_section && /^[[:space:]]*$/ { if (got) exit; next }
            in_section                     { printf "%s ", $0; got = 1 }
        ' "$proj/PLAN.md" 2>/dev/null | sed 's/[[:space:]]*$//'
    }

    # A finished plan gets the goal injected on EVERY fresh session, not only on
    # resume with the skill already loaded. This is the turn where the old bug
    # bit: a closed plan from a prior task left both gates open, nothing put the
    # previous goal in front of the model, and the next unrelated request went
    # straight to implementing under the last task's authorisation.
    if plan_finished "$proj"; then
        goal=$(section 'done when')
        [ -n "$goal" ] || goal="(no 'Done when' section found)"
        jq -n --arg goal "$goal" --arg proj "$proj" '{
          hookSpecificOutput: {
            hookEventName: "SessionStart",
            additionalContext: (
              "PLAN.md at " + $proj + " is marked ## Finished: the problem it describes has shipped.\n\n" +
              "ITS GOAL WAS: " + $goal + "\n\n" +
              "Writes under that directory are denied until this is resolved. Before touching code there, decide which this is:\n" +
              "- Covered by that goal (a fix or follow-up to what shipped): say so and ask the user to delete the ## Finished line.\n" +
              "- A new problem: run the software-design skill, settle it WITH THE USER — ask, do not assume — and rewrite PLAN.md.\n\n" +
              "Do not infer that a closed or finished plan authorises work on a different problem."
            )
          }
        }'
        exit 0
    fi

    transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
    [ "$(skill_loaded "$transcript")" = "true" ] || exit 0
    [ "$source" = "startup" ] && exit 0

    goal=$(section 'done when')
    [ -n "$goal" ] || goal="(no 'Done when' section found in PLAN.md)"

    # Language and tooling decide what a declaration can even look like, so the
    # stack has to survive a compaction alongside the goal.
    stack=$(section 'stack')
    [ -n "$stack" ] || stack="(no 'Stack' section in PLAN.md — ask before cutting symbols)"

    jq -n --arg goal "$goal" --arg stack "$stack" '{
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: (
          "A software-design loop is running in this directory: PLAN.md exists and holds the approved problem statement.\n\n" +
          "GOAL: " + $goal + "\n" +
          "STACK: " + $stack + "\n\n" +
          "Binding rules for every turn here, enforced by hooks, not by your judgement:\n" +
          "- The architecture lives in the source tree. No DESIGN.md, no architecture prose, no sketch that becomes code later.\n" +
          "- Never implement. Every body this loop creates is todo!() or equivalent; declarations may not be stubbed. Existing code is moved, never authored — after a move, edit existing code only to make the tree compile again (imports, paths, renamed call sites), never to change what a body does.\n" +
          "- One pass covers three axes in order: 1 code organization, 2 primitives as concrete symbols with their invariant as a doc comment above each declaration, 3 how those symbols interact at runtime (threads, ownership across them, handover, sync/async, backpressure).\n" +
          "- Every turn ends with a render and nothing after it. Which of the two depends on where the work stands:\n" +
          "  PROBLEM <n> / DONE WHEN / IN / OUT / BUDGETS / FAILURES / NON-GOALS / STACK / EXISTING / UNKNOWNS, while a problem is still being settled with the user.\n" +
          "  ITERATION <n> / GOAL / 1 CODE ORGA / 2 PRIMITIVES / 3 INTERACTION / DELTA / OPEN, once PLAN.md holds that problem and symbols are being cut.\n" +
          "  Only ITERATION is held to its citations: rows are read off the files on disk, and a file:line that does not resolve is a fabricated row and the turn will be rejected.\n" +
          "  Axis 2 is clustered one group per file: `<path>  uses  <clusters it depends on>`, then rows `:<line>  <kind>  <symbol>  <repr>` with the invariant under each behind `!`. A `:<line>` row with no path header above it is rejected.\n" +
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
