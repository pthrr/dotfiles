---
name: obsidian
description: The user's personal knowledge base lives in an Obsidian vault accessible via the `obsidian` CLI. Use when the user asks a technical question, starts research on a topic, mentions their notes, vault, or daily note, or wants to create or embellish a note. Always search the vault first before answering technical questions from memory.
---

# Obsidian Vault

Interact with the user's vault through the `obsidian` CLI.

## Reading (direct)

- `obsidian search query="..."` — search notes
- `obsidian read path="..."` — read a note
- `obsidian daily` — read today's daily note
- `obsidian tasks` — list tasks across the vault

## Writing (staged for review)

Never write directly to the vault. All changes go to an `inbox/` folder inside the vault for manual review.

- New note `Foo.md` → write to `inbox/Foo.md`
- Changes to existing `Bar.md` → write the full updated version to `inbox/Bar.md`

The user will review and manually migrate files from `inbox/` into the vault.

Stage with: `obsidian create name="inbox/<name>" content="..."`

## Workflows

### Check references

1. `obsidian search query="<topic>"` to find relevant notes
2. `obsidian read path="<note>"` to get the contents
3. Summarize or cross-reference findings for the user

### Embellish a note

1. `obsidian read path="<note>"` to get current contents
2. Improve the note: add detail, fix structure, add links, fill gaps
3. Stage the improved version: `obsidian create name="inbox/<note>" content="<improved>"`

### Create a note

1. Gather context from the conversation or vault
2. `obsidian create name="inbox/<title>" content="<body>"`
3. Use wikilinks `[[...]]` for internal links

## Guidelines

- Use Obsidian markdown: `[[wikilinks]]`, `#tags`, `---` frontmatter
- Preserve existing frontmatter when embellishing notes
- When embellishing, keep the author's voice — add substance, don't rewrite style
- Search the vault first before creating duplicates
- Keep notes terse: brief definitions, named theorems, bulleted options
- No prose, no filler, no elaboration — dense reference material over explanations
