# Approval protocol

Reads and recognized read-only shell commands are free. Direct file writes to
PLAN.md or the following trees are free: ~/.claude, ~/.codex, ~/.agents,
~/.config/opencode, ~/.local/share/opencode, /tmp, and ~/tmp. Checks use resolved
file targets, including every endpoint of a patch. A shell working directory
never qualifies a command for a path exemption. Other shell commands require
approval for the session's current proposal regardless of working directory.

One proposal is current per client/session. Showing a valid PLAN.md in full
records its path, content hash, file identity and unique version ID. A subsequent
human message exactly equal to lowercase `ok` approves that version. Whitespace,
punctuation, yes/y, and text following ok do not count. An ok received before
presentation cannot approve a future proposal.

Any other human message pauses mutation while preserving the open proposal and
allowing reads. Another exact ok resumes its unchanged remainder. Synthetic
messages neither grant approval nor replace the last human message. Codex Stop
feedback is correlated by its complete uniquely tagged text; the bridge does not
accept a feedback substring as provenance.

A revision creates a new version requiring presentation and approval. Re-showing
an unchanged version preserves approval. Ordinary assistant turn endings do not
close the batch. Deleting PLAN.md clears the proposal and its approval; recreating
identical content requires a new version, presentation and ok. File identity also
invalidates approval when a plan is replaced between hook events.

Human messages are published atomically before taking the policy lock. Each
mutation checks that the human event is still current before and after policy
validation, so a question can revoke an approval check already in progress.
Client/session state is serialized with flock and persisted atomically. Old
presentation-history state migrates without carrying approval forward. Reads and
known exempt writes remain available if state storage is unavailable.

A non-ok human message closes the gate before any subsequent mutation. The
OpenCode bridge requests session.abort when a mutation is running. Codex and
Claude use their client interrupt controls; the prompt hook also requests
cancellation in model context. Cancellation is best effort and does not reverse
completed writes. These hooks authorize operations; they do not sandbox arbitrary
side effects of approved programs.
