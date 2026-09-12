#!/usr/bin/env bash
# PreToolUse gate for Write|Edit. Denies the edit unless the most recent user
# text message contains "yes", "y", or "ok" (case-insensitive, word-bounded).
# The default posture is discussion: the agent proposes, the user confirms
# with one word, the agent edits.
#
# The check ignores tool_result and other non-text parts on user-role messages,
# so a bare tool_result turn does not act as consent.
#
# Exit 2 is the blocking code: stderr goes back to the model as the reason.
#
# Consent must come from a human, and the user role is not proof of one: the
# harness injects its own messages under that role, as a bare string rather than
# the text-part array typed input arrives as. Nothing in the record distinguishes
# them — isMeta, isCompactSummary and subtype are all null on both — so they are
# recognized by the tag they open with, and there are two distinct reasons to:
#
#   forged consent   <local-command-stdout> is the output of a `!` command, i.e.
#                    arbitrary text. `test foo ... ok`, or an ls listing a file
#                    named `y`, would satisfy the grep below and authorize an
#                    edit nobody asked for. adapter.ts already closes this hole
#                    for Codex stopFeedback; this is the same hole on this path.
#   displaced consent  a <task-notification> lands when a background command
#                    exits, so any long-running command silently spent the "ok"
#                    the user had just given and cost them another one. Same for
#                    <command-name>, which blocked the very slash commands whose
#                    job is to apply edits (/simplify, /code-review --fix).
#
# Both are fixed by skipping these messages entirely, so the last genuine human
# text governs — exactly what the tool_result filter below already does.
#
# The tag is matched on the joined text whatever shape the message arrived in,
# rather than only on the string shape the harness currently uses. That costs a
# human who opens a message with one of these tags verbatim their consent, and
# they retype a word. Keying it to the string shape instead would read cleaner
# and fail the other way: if the harness ever wraps these in a text part, the
# check would pass them through as typed and the forgery above is live again.
# Deny a human by accident, never authorize the harness by accident.

set -uo pipefail

input=$(cat)

transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
if [ ! -f "$transcript" ]; then
    echo "ask-first: no transcript to check; edit denied by default." >&2
    exit 2
fi

# Most recent user-authored text, joined across content parts. Empty user
# messages (tool_result only) are filtered out so they cannot inherit consent
# from an even earlier message.
last_user=$(jq -rs '
    [ .[]
      | select(.type == "user")
      | (.message.content // [])
      | if type == "array" then
          map(select(.type == "text") | .text) | join("\n")
        else . end
    ]
    | map(select(. != null and . != ""))
    | map(select(test("^<(task-notification|command-name|local-command-caveat|local-command-stdout)>") | not))
    | last // ""
' "$transcript" 2>/dev/null) || last_user=""

if printf '%s' "$last_user" | grep -qiE '\b(yes|y|ok)\b'; then
    exit 0
fi

echo "ask-first: this edit was not authorized in the last user message." >&2
echo "Default here is to propose first and wait. Reply with a plan; do not call" >&2
echo "Write or Edit until the user's most recent message contains \"yes\", \"y\", or \"ok\"." >&2
exit 2
