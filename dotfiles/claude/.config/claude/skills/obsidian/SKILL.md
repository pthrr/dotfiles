---
name: obsidian
description: The user's personal knowledge base lives in Obsidian. Always search the vault first when the user asks a technical question or starts research on a topic. Also use when creating or embellishing notes.
argument-hint: "<action> [query or note path]"
allowed-tools:
  - Bash
---

# Obsidian Vault

Use the `obsidian` CLI to interact with the user's vault.

## Available commands

- `obsidian search query="..."` — search notes in the vault
- `obsidian read path="..."` — read a note's contents
- `obsidian create name="..." content="..."` — create a new note
- `obsidian create name="..." template=...` — create from template
- `obsidian daily` — open/read today's daily note
- `obsidian tasks` — list tasks across the vault

## Workflows

### Check references
1. `obsidian search query="<topic>"` to find relevant notes
2. `obsidian read path="<note>"` to get the contents
3. Summarize or cross-reference findings for the user

### Embellish a note
1. `obsidian read path="<note>"` to get current contents
2. Improve the note: add detail, fix structure, add links, fill gaps
3. Write back with `obsidian create name="<note>" content="<improved>"`

### Create a note
1. Gather context from the conversation or vault
2. `obsidian create name="<title>" content="<body>"`
3. Use wikilinks `[[...]]` for internal links

## Guidelines

- Use Obsidian markdown: `[[wikilinks]]`, `#tags`, `---` frontmatter
- Preserve existing frontmatter when embellishing notes
- When embellishing, keep the author's voice — add substance, don't rewrite style
- Search the vault first before creating duplicates
- Use the daily note for quick captures and task logging
- Keep notes terse and concise: brief definitions, named theorems, bulleted options
- No prose, no filler, no elaboration — dense reference material over explanations
