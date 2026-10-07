#!/usr/bin/env bash
# Three modes, all of them always installed. Only the write gate is universal;
# the other two do nothing until the software-design skill is loaded BY HAND.
#
#   pre-write  PreToolUse on Write|Edit — no write lands without a PLAN.md above
#              it. Universal: every project can and should have one, and this
#              holds whether or not the skill was ever loaded.
#   stop       Stop — once the skill is loaded, a turn must end in the fixed
#              render for the loop it is in. Without the skill, turn ends are
#              unrestricted.
#   activate   SessionStart — on resume/compact only, re-inject the loop's rules
#              so they survive a compaction. Noop on a fresh session: that is
#              where the user implements, and arming there would re-enter a loop
#              they were handed the tree out of.
#
# Two loops, read off PLAN.md, never chosen by the model:
#
#   no PLAN.md above  -> the PROBLEM loop. Every Write/Edit is denied except
#   the work             PLAN.md itself, so the problem must be settled WITH THE
#                        USER before any code exists. With the skill loaded,
#                        every turn owes a PROBLEM block and nothing else — the
#                        write gate means a DESIGN block has no files to cite.
#   PLAN.md present   -> the DESIGN loop. Writes allowed. With the skill loaded,
#                        a turn that wrote something owes a DESIGN block, and
#                        that block is checked against the tree: the files it
#                        names must exist and the symbols it names must be in
#                        them. A render that describes intent is rejected.
#
# There is no marker and no third state: nothing on disk changes what the hooks do.
# The user signs off twice — once on the problem, once on the design — and
# implementation happens in a session that never armed the loop, so no file has to
# carry a mode. `## Closed` and `## Finished` were deleted for exactly that: they
# granted permission, so they went stale. `## Accepted`, which the handover appends,
# is the opposite by construction — no hook reads it, so it records what happened
# without being able to authorize anything.
#
# This stops a model that drifts. It is not proof against one actively working
# around it — a model can decline to load the skill and never arm any of it.
# Drift is the actual failure mode.
#
# Exit 2 is the blocking code: stderr goes back to the model as the reason.

set -uo pipefail

mode=${1:-}
input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd=$PWD

# Whether the software-design skill has been invoked in a transcript. This is a
# tool_use record, i.e. a deliberate load, never an inference from a file read.
# Prints "true" or "false"; a missing or unreadable transcript is "false".
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

# The whole paragraph under a heading, not its first line: a one-sentence goal
# still wraps, and half a sentence is worse than none.
section() {
    awk -v want="$1" '
        tolower($0) ~ "^#+[[:space:]]*" want "[[:space:]]*:?[[:space:]]*$" { in_section = 1; next }
        in_section && /^#/             { exit }
        in_section && /^[[:space:]]*$/ { if (got) exit; next }
        in_section                     { printf "%s ", $0; got = 1 }
    ' "$2/PLAN.md" 2>/dev/null | sed 's/[[:space:]]*$//'
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

    # Harness-owned trees: every harness's config, state, memory and session
    # scratch. A design plan is meaningless in any of them, and the gate was
    # breaking the agent rather than restraining it — memory writes were denied
    # outright, so behaviour the system prompt mandates could not run at all.
    #
    # Whole directories, not the state paths inside them. `*` spans slashes in a
    # case pattern, so one entry per tree covers everything beneath it.
    #
    # A dotfile directly in $HOME is not covered
    # and cannot be: the gate keys on the containing directory, so reaching those
    # means whitelisting $HOME, which would ungate every non-repo tree under it.
    # Home Manager's links are read-only; edit their sources in the dotfiles repo.
    home=${HOME:-/nonexistent}
    tmp=${TMPDIR:-/tmp}
    case $target_dir in
        "$home"/.claude | "$home"/.claude/* | \
        "$home"/.codex | "$home"/.codex/* | \
        "$home"/.agents | "$home"/.agents/* | \
        "$home"/.config/opencode | "$home"/.config/opencode/* | \
        "$home"/.local/share/opencode | "$home"/.local/share/opencode/* | \
        "$tmp"/claude-* | \
        /tmp/opencode | /tmp/opencode/*) exit 0 ;;
    esac

    find_plan "$target_dir" >/dev/null && exit 0

    echo "design-loop: no non-empty PLAN.md at or above $target_dir." >&2
    echo "The problem loop runs first: settle the problem statement WITH THE USER —" >&2
    echo "ask, do not assume — get their sign-off, and write it to PLAN.md. Code after." >&2
    exit 2
    ;;

stop)
    # Set on a turn this hook already blocked; re-blocking would loop forever.
    [ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

    transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
    [ -f "$transcript" ] || exit 0

    # Everything below is the skill adding to the universal gate. Without a
    # deliberate load, PLAN.md alone means "the problem is settled before code" —
    # it does not put anyone in a loop, and turn ends stay free. A fresh session
    # is how implementation gets free turn ends with no marker written anywhere.
    [ "$(skill_loaded "$transcript")" = "true" ] || exit 0

    proj=$(find_plan "$cwd") || proj=""

    # What a turn owes is decided by the plans over the files it actually wrote.
    # A turn that wrote nothing, or wrote only outside every plan — a sibling
    # checkout, a path past the repo boundary — is not design work.
    #
    # Read from the transcript this hook already parses, so nothing is carried
    # between invocations.
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

    if [ -z "$proj" ]; then
        # The problem loop. It writes nothing but PLAN.md, so arming on what the
        # turn wrote would mean it never owes anything — which is how the loop
        # that is supposed to run WITH THE USER quietly skipped its own render.
        armed=true
    else
        armed=false
        while IFS= read -r path; do
            [ -n "$path" ] || continue
            find_plan "$(dirname "$path")" >/dev/null && armed=true
        done <<TOUCHED
$touched
TOUCHED
    fi
    [ "$armed" = true ] || exit 0

    # Every assistant text record since the last user turn, joined.
    #
    # Not "the last assistant record": one turn is written as several records
    # split by content type — thinking, tool_use, text — so the last record is
    # routinely a thinking or tool_use one carrying no text at all, and pulling
    # text off it yields "". An empty string then reports as every marker
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

    design_missing=()
    for marker in 'DESIGN ' 'GOAL' '1 CODE ORGA' '2 LOGICAL ARCH' '3 INTERACTION' 'DELTA' 'OPEN'; do
        printf '%s\n' "$last" | grep -q "^${marker}" || design_missing+=("$marker")
    done

    problem_missing=()
    for marker in 'PROBLEM ' 'DONE WHEN' 'IN / OUT' 'BUDGETS' 'FAILURES' 'NON-GOALS' 'STACK' 'EXISTING' 'UNKNOWNS'; do
        printf '%s\n' "$last" | grep -q "^${marker}" || problem_missing+=("$marker")
    done

    # With no plan above the work, nothing has been settled and only PROBLEM can
    # be right. Accepting DESIGN there let a model skip the loop that exists to
    # be run with the user, by describing an existing tree it had not agreed to.
    # Where a plan DOES govern, both shapes count: a nested subtree can be in its
    # own problem loop under an already-settled parent.
    if [ -z "$proj" ]; then
        if [ ${#problem_missing[@]} -ne 0 ]; then
            echo "design-loop: no PLAN.md above $cwd, so this is the problem loop and the turn" >&2
            echo "must end with a PROBLEM block (missing ${problem_missing[*]})." >&2
            echo "Settle the problem WITH THE USER — one ASK per pass — and stop for their" >&2
            echo "sign-off. Only then is PLAN.md written and the design loop entered." >&2
            exit 2
        fi
        shape=problem
    elif [ ${#design_missing[@]} -eq 0 ]; then
        shape=design
    elif [ ${#problem_missing[@]} -eq 0 ]; then
        shape=problem
    else
        echo "design-loop: no well-formed render (DESIGN missing ${design_missing[*]};" >&2
        echo "PROBLEM missing ${problem_missing[*]})." >&2
        echo "End the turn with the fixed block from the software-design skill — same shape" >&2
        echo "every time, no additions, no prose after it — then stop and wait for the" >&2
        echo "user's sign-off." >&2
        exit 2
    fi

    # Only DESIGN is checked against the tree. A PROBLEM block cites evidence in
    # prose — a line range, a bare filename — which is not a row read off disk.
    [ "$shape" = "design" ] || exit 0

    [ -n "$proj" ] || proj=$cwd

    # The paths named in axis 1. Each must exist: the axis claims a file or a
    # directory was cut, and the loop's whole premise is that the design lives in
    # the tree rather than in the block describing it.
    # Scoped to the DESIGN block, not to the axis headings alone: INTENT carries
    # the same three, and its paths are proposals that do not exist yet — checking
    # them for existence rejects the turn for the one thing INTENT is allowed to
    # do. Latching on `^DESIGN ` and clearing on `^INTENT ` is order-independent;
    # clearing `inp` alone would not be, because the next axis heading sets it
    # again. The shape check has already established a `^DESIGN ` line is present.
    orga_paths() {
        awk '
            /^DESIGN /        { ind = 1 }
            /^INTENT /        { ind = 0; inp = 0 }
            !ind { next }
            /^1 CODE ORGA/    { inp = 1; next }
            /^2 LOGICAL ARCH/ { inp = 0 }
            !inp { next }
            $1 ~ /^[A-Za-z0-9_.\/-]+$/ && $1 ~ /[.\/]/ { print $1 }
        '
    }

    # Axis 2 is clustered: the path is written once on a cluster header and each
    # row under it cites a bare `:<line>`. Rows expand to `path|:line|symbol` so
    # all three facts get checked together. A row with no header above it expands
    # to a sentinel that fails — otherwise the shortened form would be a hole
    # where a row cites nothing and passes. Scoped to axis 2, so a path in axis 1
    # cannot supply a header for rows that never had one, and a `:<line>` under
    # axis 3 or in OPEN is not read as a declaration.
    arch_rows() {
        awk '
            /^DESIGN /        { ind = 1 }
            /^INTENT /        { ind = 0; inp = 0; path = "" }
            !ind { next }
            /^2 LOGICAL ARCH/ { inp = 1; next }
            /^3 INTERACTION/  { inp = 0 }
            !inp { next }
            $1 ~ /^[A-Za-z0-9_.\/-]+\.[A-Za-z0-9]+$/ { path = $1; next }
            $1 ~ /^:[0-9]+$/ {
                # Drop the argument list, then keep identifier characters and the
                # path separator. Truncating at the first non-word character
                # instead reduced `TagIndex::build(notes: &[Note])` to `TagIndex`,
                # which matches the type declaration, every impl block and every
                # other method — so the row located nothing in particular.
                sym = $3
                sub(/\(.*$/, "", sym)
                gsub(/[^A-Za-z0-9_:]/, "", sym)
                print (path == "" ? "<no-cluster-header>" : path) "|" substr($1, 2) "|" sym
            }
        '
    }

    # `uses` on a cluster header is a dependency edge, emitted as `from to` for
    # tsort. Every render states the direction and nothing ever read it: the awk
    # above captures the path and drops the rest of the header line, so a cycle
    # rendered clean and surfaced at link time. Acyclicity is the one requirement
    # the skill states three times, and this is the only place it is checkable.
    # Same scoping, and here it matters most: merging INTENT's proposed edges with
    # DESIGN's reported ones into one graph manufactures a cycle that exists in
    # neither block, whenever a proposal reverses a current dependency.
    depends_edges() {
        awk '
            /^DESIGN /        { ind = 1 }
            /^INTENT /        { ind = 0; inp = 0 }
            !ind { next }
            /^2 LOGICAL ARCH/ { inp = 1; next }
            /^3 INTERACTION/  { inp = 0 }
            !inp { next }
            $1 ~ /^[A-Za-z0-9_.\/-]+\.[A-Za-z0-9]+$/ && $2 == "uses" {
                for (i = 3; i <= NF; i++) {
                    to = $i
                    sub(/,$/, "", to)
                    if (to != "-" && to != "") print $1 " " to
                }
            }
        '
    }

    # Resolve a rendered path against the session root, then as given.
    target_of() {
        [ -f "$cwd/$1" ] && { printf '%s\n' "$cwd/$1"; return 0; }
        [ -f "$1" ] && { printf '%s\n' "$1"; return 0; }
        return 1
    }

    bad=()

    # Axis 1: the files and directories exist.
    while read -r path; do
        [ -n "$path" ] || continue
        [ -e "$cwd/$path" ] || [ -e "$path" ] || bad+=("$path (1 CODE ORGA names it, but nothing is there)")
    done < <(printf '%s\n' "$last" | orga_paths | sort -u)

    # Axis 2: the declaration is where the row says, and the symbol is in it.
    while IFS='|' read -r path line sym; do
        [ -n "$path" ] || continue
        if [ "$path" = "<no-cluster-header>" ]; then
            bad+=(":$line (a row with no cluster header above it)")
            continue
        fi
        if ! target=$(target_of "$path"); then
            bad+=("$path:$line (no such file)")
            continue
        fi
        if [ -z "$sym" ]; then
            bad+=("$path:$line (no symbol in the row)")
            continue
        fi

        # The cited line has to be where the symbol actually is. Until now the
        # line was only range-tested against the file length and the symbol was
        # grepped file-wide, so neither fact constrained the other and `:1` on
        # every row was a clean render. Citing a location that is not checked
        # against the thing it locates is decoration.
        hits=$(grep -nF -- "$sym" "$target" | cut -d: -f1)
        if [ -z "$hits" ]; then
            bad+=("$path:$line (the row declares '$sym', which is not in the file)")
            continue
        fi

        # A window rather than an exact line: the invariant is a doc comment above
        # the declaration and attributes sit between the two, so either end of
        # that small block is a fair citation.
        near=false
        for hit in $hits; do
            delta=$((hit - line))
            [ "$delta" -lt 0 ] && delta=$(( -delta ))
            [ "$delta" -le 3 ] && near=true
        done
        [ "$near" = true ] ||
            bad+=("$path:$line (the row declares '$sym', found at :$(printf '%s\n' "$hits" | head -1))")
    done < <(printf '%s\n' "$last" | arch_rows | sort -u)

    # Acyclicity, from the `uses` headers. tsort exits nonzero and names the loop
    # members on stderr; a graph with no edges at all is trivially fine.
    edges=$(printf '%s\n' "$last" | depends_edges | sort -u)
    if [ -n "$edges" ] && ! loop=$(printf '%s\n' "$edges" | tsort 2>&1 >/dev/null); then
        echo "design-loop: the dependency direction in 2 LOGICAL ARCH is cyclic:" >&2
        printf '%s\n' "$loop" | sed 's/^tsort: /  /' >&2
        echo "Fix the direction in the tree — extract the shared vocabulary into a leaf, or" >&2
        echo "move the declaration that forced the back edge — then render where it landed." >&2
        exit 2
    fi

    # Any other file:line written in prose — DELTA, OPEN, a sentence — still has
    # to resolve. Those are not declarations, so only the location is checked.
    while read -r ref; do
        [ -n "$ref" ] || continue
        path=${ref%:*}
        line=${ref##*:}
        if ! target=$(target_of "$path"); then
            bad+=("$ref (no such file)")
            continue
        fi
        count=$(wc -l <"$target")
        [ "$line" -le $((count + 1)) ] || bad+=("$ref (file ends at line $count)")
    done < <(printf '%s\n' "$last" | grep -oE '[A-Za-z0-9_./-]+\.[A-Za-z0-9]+:[0-9]+' | sort -u)

    if [ ${#bad[@]} -ne 0 ]; then
        echo "design-loop: the render does not match the tree:" >&2
        printf '  %s\n' "${bad[@]}" >&2
        echo "Every file and every symbol in a DESIGN block is written to disk before the" >&2
        echo "block is emitted — the block reports the tree, it does not promise one. Cut" >&2
        echo "the file, declare the symbol, then cite where it actually landed." >&2
        exit 2
    fi

    # A `ceiling:` in OPEN claims a deliberate simplification is marked at the
    # decision. Claiming it and not writing the marker is how the ledger rots.
    printf '%s\n' "$last" | grep -q 'ceiling:' || exit 0

    # Tracked and untracked-but-not-ignored files only. The recursive grep this
    # replaces walked gitignored trees inside the project — a dev shell keeping a
    # 3.2 GB .rustup and a 167 MB .cargo in-repo — and blew the adapter's 20 s
    # hook timeout. A timeout there does not fail open: runCheck throws on it, so
    # the Stop hook broke rather than the check being slow.
    #
    # --untracked is load-bearing, not a speedup: the files this loop just cut are
    # new, so a tracked-only search would never see the marker it is looking for.
    # The narrowing is that a marker inside an ignored file no longer counts,
    # which is right — the ledger belongs in the source that ships.
    #
    # --no-recurse-submodules because git grep refuses --untracked alongside
    # submodule recursion, and that can be on from the user's config rather than
    # from anything this call passes.
    if git -C "$proj" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$proj" grep --no-recurse-submodules -qE --untracked \
            '(#|//|--|;) ?design:' -- . ':(exclude,glob)**/PLAN.md' 2>/dev/null && exit 0
    else
        # No work tree to ask. Same walk as before, plus the toolchain trees that
        # caused this — otherwise the bug just moves to non-git projects.
        grep -rqE '(#|//|--|;) ?design:' "$proj" \
            --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=target \
            --exclude-dir=.venv --exclude-dir=.rustup --exclude-dir=.cargo \
            --exclude=PLAN.md 2>/dev/null && exit 0
    fi

    echo "design-loop: OPEN claims a ceiling: but no design: marker exists under $proj." >&2
    echo "A ceiling is recorded at the decision, not only in the render — the render" >&2
    echo "scrolls away. Add a comment naming the ceiling AND the upgrade path, e.g." >&2
    echo "  // design: single-threaded over disjoint ranges, split per range if build latency matters" >&2
    exit 2
    ;;

activate)
    # Only a resume or a compaction: those pick up a session that was already
    # armed by hand, and the rules have to survive losing the transcript. A fresh
    # session is where the user implements — injecting there would re-arm a loop
    # that was signed off, and activation is manual, never inferred.
    proj=$(find_plan "$cwd") || exit 0

    source=$(printf '%s' "$input" | jq -r '.source // empty')
    case "$source" in
        resume|compact) ;;
        *) exit 0 ;;
    esac

    transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
    [ "$(skill_loaded "$transcript")" = "true" ] || exit 0

    goal=$(section 'done when' "$proj")
    [ -n "$goal" ] || goal="(no 'Done when' section found in PLAN.md)"

    # Language and tooling decide what a declaration can even look like, so the
    # stack has to survive a compaction alongside the goal.
    stack=$(section 'stack' "$proj")
    [ -n "$stack" ] || stack="(no 'Stack' section in PLAN.md — ask before cutting symbols)"

    jq -n --arg goal "$goal" --arg stack "$stack" '{
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: (
          "A software-design loop is running here: PLAN.md exists and holds the problem the user signed off, so you are in the DESIGN loop.\n\n" +
          "GOAL: " + $goal + "\n" +
          "STACK: " + $stack + "\n\n" +
          "Binding rules for every turn here. The render and the tree check are enforced by hooks; the rest bind you because they are the loop, not because something stops you:\n" +
          "- The design lives in the source tree. No DESIGN.md, no architecture prose, no sketch that becomes code later.\n" +
          "- Never implement. Implementation is the user'"'"'s, in their own session. Every body this loop creates is todo!() or equivalent; declarations may not be stubbed. Existing code is moved, never authored — after a move, edit existing code only to make the tree compile again (imports, paths, renamed call sites), never to change what a body does.\n" +
          "- One pass covers three dimensions in order, in the language and stack above: 1 code organization (real files, one concept each), 2 logical architecture (the symbols, each with its invariant as a doc comment above the declaration, and the dependency direction between files), 3 interaction (the design and communication patterns between those symbols: sync or async, request-response or fire-and-forget, timeouts, backpressure, idempotency).\n" +
          "- Every turn ends with a render and nothing after it:\n" +
          "  DESIGN <n> / GOAL / 1 CODE ORGA / 2 LOGICAL ARCH / 3 INTERACTION / DELTA / OPEN.\n" +
          "  2 LOGICAL ARCH is clustered one group per file: `<path>  uses  <files it depends on>`, then rows `:<line>  <kind>  <symbol>  <repr>` with the invariant under each behind `!`. A `:<line>` row with no path header above it is rejected.\n" +
          "  The block is checked against the tree before the turn is allowed to end: every path in 1 CODE ORGA must exist, the symbol each row declares must be AT the `:<line>` it cites (within a few lines, for the doc comment above it), and the `uses` graph must be acyclic. Write the files and the declarations FIRST, then report where they landed. A render that promises a tree instead of reporting one is rejected.\n" +
          "- A write needs the user'"'"'s consent word in their latest message, so one pass is two turns. On a turn you cannot write, propose in the INTENT shape and stop: INTENT <n> / GOAL / 1 CODE ORGA / 2 LOGICAL ARCH / 3 INTERACTION / WHY / ASK — the same three axes as DESIGN so every axis is proposed before it exists, with no `:<line>` because nothing is on disk yet. On the turn after their ok, write it and report it as DESIGN, same <n>. Never propose a design in prose. INTENT is legal only on a turn that wrote nothing; write something and end with INTENT and the turn is rejected.\n" +
          "- The loop does not self-terminate and nothing you write into PLAN.md releases it. The user'"'"'s sign-off is what ends it; the hooks catch drift, not a model that decides to walk out. Do not ask whether to continue; render and stop.\n" +
          "- On that sign-off, append `## Accepted` to PLAN.md with the date, the pass number and one line on what the tree now is, then end the turn with the final DESIGN block, its DELTA reading `PLAN.md: ## Accepted appended`. No hook reads that record; it exists so a later session can tell an accepted design from an abandoned one.\n" +
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
