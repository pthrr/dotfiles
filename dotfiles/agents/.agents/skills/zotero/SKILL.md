---
name: zotero
description: The user's academic library lives in Zotero and is searchable through the `zotero` CLI. Use when the user asks about papers, literature, citations, or research topics, mentions Zotero, or wants to find, read, or cite a source. Always search the library before searching the web for academic material.
---

# Zotero Library

Read the user's Zotero library through the `zotero` CLI. Run `zotero` with no
arguments for the command list.

**Prerequisite:** Zotero must be running and the local API enabled in
Settings → Advanced → "Allow other applications on this computer to communicate
with Zotero". The CLI prints this instruction on 403.

## Searching

- `zotero search "exact phrase"` — title, creators and year
- `zotero search "concept" --fulltext` — also searches indexed PDF and note text
- `zotero search "term" --type journalArticle --tag foo --collection KEY --limit 20`
- `zotero recent 10` — recently added top-level items
- `zotero collections` — collection keys, counts and paths
- `zotero collection KEY` — items in a collection

Search before answering a research question and before fetching a paper from
the web. Results are `key<TAB>year<TAB>type<TAB>creators<TAB>title`. Queries are
phrase searches; use a distinctive phrase. Add `--json` for raw API JSON.

## Reading

- `zotero item KEY` — metadata, creators, tags, collections, abstract, children
- `zotero item KEY --json` — raw API item plus children
- `zotero file KEY` — absolute attachment paths, PDFs first
- `zotero notes KEY` — child notes as text
- `pdftotext "$(zotero file KEY | head -1)" -` — read the first attachment

`--fulltext` returns matching items, not snippets. Open the matching PDF with
`pdftotext` to read the context.

## Citing

- `zotero bib KEY [KEY...]` — BibTeX

Cite by key in prose, e.g. "Wadler [MK49CT9T]". Do not invent citations; export
the user's actual item.

## Rules

- Read-only. Never add, edit or delete Zotero items, notes, collections or
  attachments. The CLI only issues GET requests.
- Do not read `~/Zotero/zotero.sqlite` directly; Zotero locks it while running.
- If the library has no relevant work, say so before searching the web.
