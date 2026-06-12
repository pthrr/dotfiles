---
name: obsidian
description: The user's personal knowledge base lives in an Obsidian vault accessible via the `obsidian` CLI. Use when the user asks a technical question, starts research on a topic, mentions their notes, vault, or daily note, or wants to create or embellish a note. Always search the vault first before answering technical questions from memory.
---

# Obsidian Vault

Interact with the user's vault through the `obsidian` CLI. Run `obsidian` with no args for the full command list.

## Reading (direct)

- `obsidian search query="..."` — search notes
- `obsidian read path="..."` — read a note
- `obsidian daily` — read today's daily note
- `obsidian tasks` — list tasks across the vault

## Writing (staged for review)

Never write directly to the vault. All changes go to an `inbox/` folder for the user to review and migrate manually.

**CLI gotcha:** use `path=` when the target has a folder component. `name=` accepts a filename only — slashes error out.

```
obsidian create path="inbox/Foo.md" content="..."             # new
obsidian create path="inbox/Foo.md" content="..." overwrite   # restage
obsidian delete path="inbox/Foo.md"                           # moves to trash
```

Multiline content: build it in a temp file, then expand via shell.

```
obsidian create path="inbox/Foo.md" content="$(cat /tmp/draft.md)"
```

### What to stage

- **New note** → full body to `inbox/<title>.md`.
- **Small edit to existing note** → diff snippet with a few lines of surrounding context to `inbox/<title>_diff.md`. Don't restage the full file for a localized change — the user reviews by eye.
- **Large rewrite** → full updated version to `inbox/<title>.md`.

## Workflows

### Check references

1. `obsidian search query="<topic>"` to find relevant notes
2. `obsidian read path="<note>"` to get the contents
3. Summarize or cross-reference findings for the user

### Embellish a note

1. `obsidian read path="<note>"` to get current contents
2. Improve the note: add detail, fix structure, add links, fill gaps
3. Stage per **What to stage** above

### Create a note

1. Gather context from the conversation or vault
2. `obsidian create path="inbox/<title>.md" content="<body>"`
3. Use wikilinks `[[...]]` for internal links

## Guidelines

- Use Obsidian markdown: `[[wikilinks]]`, `#tags`, `---` frontmatter
- Preserve existing frontmatter when embellishing notes
- When embellishing, keep the author's voice — add substance, don't rewrite style
- Search the vault first before creating duplicates
- Keep notes terse: brief definitions, named theorems, bulleted options
- No prose, no filler, no elaboration — dense reference material over explanations
