---
name: obsidian
description: The user's personal knowledge base lives in an Obsidian vault accessible via the `obsidian` CLI. Use when the user asks a technical question, starts research on a topic, mentions their notes, vault, or daily note, or wants to create or embellish a note. Always search the vault first before answering technical questions from memory.
---

# Obsidian Vault

Interact with the user's vault through the `obsidian` CLI. Run `obsidian` with
no args for the full command list.

## Reading (direct)

- `obsidian search query="..."` — search notes
- `obsidian read path="..."` — read a note
- `obsidian daily` — read today's daily note
- `obsidian tasks` — list tasks across the vault

Search before answering a technical question, and before creating a note that
may already exist.

## Writing (staged for review)

Never write directly to the vault. Everything goes to `inbox/` for the user to
review and migrate by hand.

```
obsidian create path="inbox/<title>.md" content="$(cat /tmp/draft.md)"             # new
obsidian create path="inbox/<title>.md" content="$(cat /tmp/draft.md)" overwrite   # restage
```

**CLI gotcha:** use `path=` when the target has a folder component. `name=`
accepts a filename only — slashes error out.

What to stage:

- **Further changes** → reuse the note's inbox file, with or without `_diff`;
  read it first. The user may have changed it too; their changes are retained
  in any case.
- **No original note** → the changes are a new file, `inbox/<title>.md`,
  without the `_diff` postfix.
- **Original note exists** → `inbox/<title>_diff.md`. It can incorporate the
  original note, which does not have to be retained verbatim.

Embellishing means reading the note first, then adding detail, structure, links
and missing pieces — preserve its frontmatter and keep the author's voice.

## Style

- Obsidian markdown: `[[wikilinks]]`, `#tags`, `---` frontmatter.
- Keep notes terse: brief definitions, named theorems, bulleted options; no
  prose, no filler, no elaboration.
- Every variable, subscript, Greek letter, operator and relation is math. Read
  [formatting](references/formatting.md) before writing or editing a note with
  math, tables or other markup.
