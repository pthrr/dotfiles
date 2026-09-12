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
    | last // ""
' "$transcript" 2>/dev/null) || last_user=""

if printf '%s' "$last_user" | grep -qiE '\b(yes|y|ok)\b'; then
    exit 0
fi

echo "ask-first: this edit was not authorized in the last user message." >&2
echo "Default here is to propose first and wait. Reply with a plan; do not call" >&2
echo "Write or Edit until the user's most recent message contains \"yes\", \"y\", or \"ok\"." >&2
exit 2
