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
obsidian create path="inbox/Foo.md" content="..."             # new
obsidian create path="inbox/Foo.md" content="..." overwrite   # restage
obsidian delete path="inbox/Foo.md"                           # moves to trash
obsidian create path="inbox/Foo.md" content="$(cat /tmp/draft.md)"   # multiline
```

**CLI gotcha:** use `path=` when the target has a folder component. `name=`
accepts a filename only — slashes error out.

What to stage:

- **New note** → full body to `inbox/<title>.md`.
- **Small edit** → diff snippet plus a few lines of context to `inbox/<title>_diff.md`. Don't restage a whole file for a localized change; the user reviews by eye.
- **Large rewrite** → full updated version to `inbox/<title>.md`.

Embellishing means reading the note first, then adding detail, structure, links
and missing pieces — preserve its frontmatter and keep the author's voice.

## Guidelines

- Obsidian markdown: `[[wikilinks]]`, `#tags`, `---` frontmatter.
- Keep notes terse: brief definitions, named theorems, bulleted options.
- No prose, no filler, no elaboration — dense reference material over explanations.
