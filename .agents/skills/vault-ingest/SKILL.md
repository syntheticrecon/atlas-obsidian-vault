---
name: vault-ingest
description: Ingest a new source from raw/ into the research wiki. Use when the user adds a file to raw/, says "ingest this source", "process this article", "read this paper into the vault", or drops a URL, YouTube link, PDF, or markdown file. Creates Sources/ page, extracts Concepts/Entities/Questions, adds bidirectional cross-links, and updates index.md, log.md, hot.md, and raw/.manifest.json. Does NOT use this for querying the wiki — see vault-query for that.
---

# Vault Ingest Skill

Process a new source document through the full ingest pipeline. This is the most-used workflow in the vault. Get it right and everything else compounds.

## When to Use

Trigger on any of:

- User says "ingest this", "process this source", "read this into the vault"
- A new file appears in `raw/` that isn't in `raw/.manifest.json`
- User provides a URL, paper, or YouTube link (fetch first, then ingest)
- User asks to "update the wiki with" a source

**Do NOT use for**: querying existing knowledge (use `vault-query`), reviewing what was already ingested (use `vault-review`), or maintenance (use `vault-maintain`).

## Prerequisites

- Read `hot.md` first to restore session context
- Read `AGENTS.md` if the schema isn't already in memory (page conventions, frontmatter, cross-linking rules)
- Locate the source in `raw/` — if the user provided a URL or YouTube link, fetch first:
  - YouTube: `bin/yt-ingest.sh <url>` (creates `raw/<slug>.md`)
  - Web article: use the `defuddle` skill or `agent-browser` skill
  - PDF: user must convert; do not attempt OCR here

## Workflow

### Step 0 — Delta check

Read `raw/.manifest.json`. Compute the source file's SHA-256 (`shasum -a 256 <file>`). If the hash matches a `status: current` entry, **skip the ingest** unless the user explicitly asks for a force re-ingest. Report "already ingested, pages: [list]" and stop.

### Step 1 — Read the source

Read the raw file. Identify the type (article, paper, thread, video, book) to drive the frontmatter. Note any embedded images — if referenced, confirm they exist under `raw/assets/`.

### Step 2 — Create or update the Sources/ page

Use `_templates/Source.md` as the scaffold. Required frontmatter: `source_file`, `url`, `date_published`, `date_ingested`, `type`, `explored: false`. Required sections: Summary, Key Claims, Concepts Extracted, Entities Mentioned, Open Questions, Related.

If a Sources/ page for this source already exists (older version arriving), switch to the Source Update workflow in AGENTS.md (preserve old version, add Version History section, walk dependent pages).

### Step 3 — Extract and place Concepts, Entities, Questions

For each distinct idea or named thing in the source:

- **Concept** (idea spanning sources, not a proper noun) → `Concepts/<Name>.md`
- **Entity** (proper noun with fixed identity: person, org, product, tool, text) → `Entities/<Name>.md`
- **Open question** (contradiction, gap, follow-up) → `Questions/<Name>.md`

**Update before create.** Search for existing pages on the topic (including via `aliases:`) before creating a new one. If in doubt, prefer Concept.

**Page creation threshold.** 2+ sources on a topic → full page. 1 source → stub (minimal frontmatter + one paragraph). Never leave dead wikilinks.

**All AI-created pages get `explored: false`.** Human reviews flip this later via `vault-review`.

**Concepts/ pages require** `## Counter-arguments` and `## Data Gaps` sections (even if "None identified yet.").

### Step 4 — Cross-link bidirectionally

- Every Concept/Entity referenced by the Sources/ page must link back to the Sources/ page
- Every Question links to the Source(s) that raised it
- Inline wikilinks in prose, first-mention-only, not link-dump sections
- Use `aliases:` in frontmatter for synonyms to prevent duplicate pages

### Step 5 — Update `index.md`

Add the new pages to the appropriate sections. Scale format to vault size (see Index Scaling Strategy in AGENTS.md).

### Step 6 — Append to `log.md`

```
## [YYYY-MM-DD] ingest | <Source Title>
Processed [[Sources/<Title>]]. Created [[Concepts/X]], [[Entities/Y]]. N new cross-links.
```

### Step 7 — Update `raw/.manifest.json`

Add an entry for the source:

```json
{
  "raw/<filename>.md": {
    "sha256": "<hex digest>",
    "ingested_at": "<ISO-8601 UTC>",
    "wiki_pages": ["Sources/...", "Concepts/...", "Entities/...", "Questions/..."],
    "status": "current"
  }
}
```

### Step 8 — Update `hot.md`

Add to Recent Changes. If the source opens an active research thread, add to Active Threads. Cap the file at ~500 words; trim older entries if needed.

### Step 9 — Report to the user

Concise summary: source title, pages created, pages updated, cross-links added, any contradictions or gaps flagged. Suggest running `vault-review` if they want to approve the new pages.

## Conflicts and Contradictions

When this source contradicts existing wiki claims, do NOT silently overwrite:

- **Supersession** (newer data replaces older): update the claim, mark the old with `> [!info] Superseded by [[<This Source>]]`
- **Contradiction** (peer disagreement): note on both Sources/ pages, create or update a Questions/ page with `status: open`, wrap contested claim in `> [!contradiction]` on Concepts/

Full detail: see "Source Conflict Workflow" in AGENTS.md.

## Verification

After ingest, quickly confirm invariants:

- Sources/ page has the source file path and `explored: false`
- Every Concept/Entity linked from the Sources page links back
- Manifest has the new entry with correct SHA
- `index.md` lists all new pages
- `log.md` has a new `## [date] ingest` entry

Use `bin/vault-health.sh` if unsure — any `ERRORS` means something's wrong.

## Output

Report to user in this format:

```
Ingested: <Source Title>
  Sources/   → <new/updated page>
  Concepts/  → [list]
  Entities/  → [list]
  Questions/ → [list] (or "none raised")

Manifest updated. Index and log updated. hot.md refreshed.

[N] pages pending review. Run `bin/review.sh` or ask me to walk the queue.
```
