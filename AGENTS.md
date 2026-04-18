# Research Vault Agent Guide

This repo is a template for an LLM-maintained Obsidian wiki. The agent maintains the wiki layer; the human curates sources and steers the research direction.

## Domain Customization

**The template is generic research. Before the first real ingest, customize this file for your domain.** The schema is meant to be co-evolved with use — treat the sections below as defaults, not laws.

Things worth editing per domain:

- **Page types**: Add or remove folders. A product-docs vault might add `Decisions/` or `Specs/`. A recipes vault might drop `Questions/` and add `Ingredients/`.
- **Frontmatter fields**: The schema table is a starting point. Add fields that matter for your domain (e.g., `journal`, `arxiv_id`, `version` for papers; `difficulty`, `time` for recipes).
- **Entity subtypes**: The default `person / org / product / tool / text` may not fit. For a biology vault: `species / gene / protein`. For a legal vault: `case / statute / judge`.
- **Confidence signals**: What makes a claim "high confidence" in your domain? Peer review? Replication? First-hand experience? Encode the rubric.
- **Counter-arguments / Data Gaps**: Mandatory on Concepts/ pages by default. If your domain is descriptive (recipes, specs) rather than adversarial (research, policy), drop this rule.
- **Cadence**: How often do you ingest? Review? Run lint? Add a "weekly rhythm" note.

When you edit the schema, also update:
- `tests/schemas/frontmatter.schema.json` (if tests are in use)
- `_templates/*.md` (so new pages match the new schema)

The `check-schema-sync.py` test catches drift between these three.

## Read First

- `methodology/llm-wiki.md`: canonical pattern for ingest, query, and wiki maintenance. Links to the original gist.
- `methodology/karpathy-thread.md`: practical workflow notes on staged autonomy and one-at-a-time ingest.
- `methodology/obsidian-skills.md`: the Obsidian-native skills this template vendors.

## Working Model

- Treat `raw/` as immutable source material. Read from it; do not edit, rename, or reorganize it unless explicitly asked.
- Treat the wiki as a persistent compiled artifact. Prefer updating existing pages over creating parallel pages.
- Do not leave durable research value in chat only. File reusable outputs back into the vault.
- Prefer small, compositional updates across the wiki over broad rewrites.

### Context Window Discipline

- Read `hot.md` first every session — it summarizes current vault state, recent changes, active threads, and pending reviews.
- Then read `index.md` for navigation.
- Limit each query round to 5-7 pages. Prefer synthesized pages (Concepts/, Entities/, Outputs/) before Sources/.
- Re-read `hot.md` after any context compaction event to restore continuity.
- Do not load entire folders speculatively. Fetch specific pages based on the current question.

## Standard Structure

- `raw/`: source documents and imports.
- `raw/assets/`: downloaded attachments referenced by raw sources.
- `Sources/`: one page per raw source.
- `Concepts/`: synthesized topic pages spanning multiple sources.
- `Entities/`: named things such as people, orgs, products, places, texts, tools.
- `Questions/`: open questions, contradictions, and follow-up investigations.
- `Outputs/`: reusable deliverables from queries.
- `index.md`: first stop for navigation; keep it updated so future sessions can navigate without re-discovering the vault.
- `log.md`: append-only record of ingest, query, and maintenance operations.

Create missing standard folders only when first needed.

### Index Scaling Strategy

Scale `index.md` to the vault size. Graduate to the next tier only when the current one starts to feel unwieldy.

- **0-20 pages**: flat list grouped by folder.
- **20-50 pages**: flat list plus a one-line description for each page.
- **50-100 pages**: group by subtopic within each folder section.
- **100+ pages**: use a Maps-of-Content (MOC) pattern — dedicated topic index pages (e.g., `Concepts/ML MOC.md`) that `index.md` links to, rather than listing every page directly.

## Required Workflows

### Ingest

When asked to process a new source from `raw/`:

0. **Delta check**: Read `raw/.manifest.json`. Compute the source file's SHA-256 hash. If it matches a recorded entry with `status: current`, skip ingest unless the user explicitly requested a force re-ingest.
1. Read the source.
2. Create or update a matching page in `Sources/`.
3. Extract claims, concepts, entities, and unresolved questions.
4. Update existing `Concepts/`, `Entities/`, and `Questions/` pages before creating new ones.
5. Add cross-links between affected pages.
6. Update `index.md`.
7. Append a concise entry to `log.md`.
8. **Update manifest**: Record the source's `sha256`, `ingested_at` (ISO 8601 UTC), the `wiki_pages` array of affected page paths, and `status: current` in `raw/.manifest.json`.

Default to one-source-at-a-time ingest, especially early in a new domain. Only ask clarification questions when the ontology is unclear enough that you would likely create bad structure.

**Manifest schema** (per source entry in `raw/.manifest.json`):

```json
{
  "sources": {
    "raw/path/to/source.md": {
      "sha256": "<hex digest of file contents>",
      "ingested_at": "2026-04-12T14:03:00Z",
      "wiki_pages": ["Sources/Source Title.md", "Concepts/Topic.md"],
      "status": "current"
    }
  }
}
```

`status` values: `current` (up to date), `updated` (re-ingested after source change), `superseded` (replaced by a newer version — see Source Update Workflow).

### Bulk Ingest

When asked to process several sources at once:

1. List all candidate sources from `raw/`.
2. Ask the user for a priority order; if they decline, use chronological order by `date_published` (fallback: filesystem mtime).
3. Ingest one at a time. Complete all wiki updates for a source before moving to the next.
4. Every 5 sources, run a **mini-lint**: scan for duplicate Concepts/Entities pages and ontology drift. Consolidate before continuing.
5. Provide a summary report at the end: sources ingested, pages created, pages updated, questions raised, duplicates merged.

### Source Update Workflow

When a new version of an existing source arrives:

1. Save the new version to `raw/` under a versioned filename (e.g., `Paper Title (v2).md`) — do not replace the old file.
2. Update the existing `Sources/` page: add a `## Version History` section noting the previous version and what changed.
3. Walk every Concept/Entity/Question page that links to this source. For each claim that depends on the old version:
   - If the new version confirms it, update the citation and leave a `> [!info]` note.
   - If the new version changes it, update the claim and mark the old one with `> [!stale]`.
   - If the new version contradicts it, follow the Source Conflict Workflow.
4. In `raw/.manifest.json`, set the old entry's `status` to `superseded` and create a new entry for the updated file with `status: current`.
5. Log as a revision, not a new source: `## [YYYY-MM-DD] update | Source Title revised to v2`.

### Source Conflict Workflow

When two sources disagree, distinguish:

- **Supersession** — newer or more authoritative data replaces older data.
  - Update the claim on affected Concepts/Entities pages.
  - Mark the old claim with `> [!info] Superseded by [[Newer Source]]`.
  - No Questions/ page needed.
- **Contradiction** — genuine disagreement between roughly peer sources.
  - Note the conflict on both `Sources/` pages.
  - Create or update a `Questions/` page capturing the disagreement, with `status: open` and `raised_by` pointing to both sources.
  - On the affected Concepts/Entities page, wrap the contested claim in `> [!contradiction]` or `> [!question] Contested` and link to the Questions/ page.

Never silently pick one source over another. If unsure which category applies, treat it as a contradiction.

### Archival and Deprecation

Mark, don't delete:

- Questions answered by a later source: set `status: resolved` on the Questions/ page and link to the resolving Sources/Concepts/Outputs page. Do not delete the question.
- Concepts/Entities replaced by a refined successor: set `status: superseded` and link to the replacement page. The old page remains navigable for history.
- Outputs/ pages whose underlying claims have changed: set `status: superseded`.

Lint passes identify archival candidates but do not auto-archive — humans confirm.

### Crystallization

When an `Outputs/` page proves repeatedly valuable (referenced from multiple other pages, cited in conversations, or stabilized after several queries), promote its durable insights into `Concepts/` or `Entities/` pages:

1. Identify the reusable claims or synthesized ideas inside the Output.
2. Create or update the relevant Concept/Entity page with those claims.
3. Cross-link the Output to the new/updated Concept/Entity.
4. Leave the Output in place with `status: current` and the `query` field so the original question/answer pairing remains discoverable.

Treat completed explorations as knowledge sources, not disposable artifacts.

### Query

When answering a research question against the vault:

1. Start with `index.md`.
2. Read the most relevant synthesized pages first, then source pages when provenance or nuance matters.
3. Answer in chat.
4. Create or update an `Outputs/` page when the result is likely to be useful again.
5. Link that output from related pages.
6. Append to `log.md` when the query materially changed the vault.

### Lint / Maintenance

When asked to clean up or health-check the vault, run the severity-tiered checklist below. `bin/vault-health.sh` automates most of these checks.

**Errors** (must fix):

- Broken wikilinks — links pointing to pages that do not exist.
  - `rg -n '\[\[[^\]]+\]\]' --type md` then verify each target exists.
- Missing required `status` frontmatter on Concepts/Entities/Questions/Outputs pages.
  - `rg -L '^status:' Concepts/ Entities/ Questions/ Outputs/`
- Dead links in `index.md` — linked pages that no longer exist.

**Warnings** (should address):

- Orphaned pages — no inbound wikilinks from any other wiki page.
- Pages with no outgoing wikilinks — likely missing cross-links.
- Stale claims — a page with `confidence: high` when newer sources have been ingested on the same topic.
  - `rg -l 'confidence: high' Concepts/ Entities/`
- Unresolved contradictions — `> [!contradiction]` callouts older than 30 days.
  - `rg -n '\[!contradiction\]' --type md`
- Duplicate pages on the same topic.
- Repeated concepts or entities mentioned across multiple pages that still lack their own page.

**Info** (nice to have):

- Pages with `explored: false` — pending human review.
  - `rg -l 'explored: false'`
- Pages with `status: seed` that have accumulated new linked sources — candidates for promotion to `developing`.
  - `rg -l 'status: seed'`
- Concepts/Entities missing `aliases` — reduces discoverability.
  - `rg -L '^aliases:' Concepts/ Entities/`
- Useful missing cross-links — unlinked mentions of known page names (see `bin/cross-linker.sh`).

## Page Conventions

- Use clear Title Case file names.
- Prefer singular names for concept and entity pages unless plural is more natural.
- Keep source page names stable and human-readable.
- Keep frontmatter light; only add fields that help navigation, provenance, or stable querying.
- If a claim is uncertain, inferred, or contested, label it clearly.
- Source-backed claims should point to the relevant `Sources/` page, and source pages should point back to the originating file in `raw/`.

### Cross-Linking Guidelines

- **Bidirectional linking**: every `Sources/` page links to the `Concepts/` and `Entities/` it informs, and each of those pages links back to the Source.
- `Questions/` pages link to the Sources/Concepts that raised them; those pages link back to the Question.
- Place wikilinks **inline in prose**, in the context where the referenced idea appears. Avoid link-dump sections at the bottom of pages — a small `## Related` section is fine for a handful of peripheral links, but the primary connections should be inline.
- **First-mention-only**: link a given concept the first time it appears on a page. Do not link the same concept repeatedly.
- Add an `aliases` field in frontmatter for synonyms so that wikilinks and search still resolve. Example:

  ```yaml
  aliases: [ML, statistical learning]
  ```

### Entity vs Concept Heuristic

- **Entity** = a proper noun with fixed identity: a specific person, organization, product, place, text, or named tool.
- **Concept** = an idea, pattern, or category that spans sources and is not a proper noun.

Examples:
- "Andrej Karpathy" → Entity. "LLM-maintained wiki" → Concept.
- "OpenAI" → Entity. "Retrieval-augmented generation" → Concept.
- "The Bitter Lesson (essay)" → Entity. "Scaling laws" → Concept.

When in doubt, prefer Concept. It is easier to promote a Concept into an Entity later than to split an Entity that has accumulated abstract claims.

### Page Lifecycle

Track page maturity with a `status` frontmatter field. Values progress:

- `seed` — stub page, one or two claims, may exist only to prevent dead wikilinks.
- `developing` — multiple sources, but synthesis still in progress or known gaps remain.
- `mature` — well-synthesized, Counter-arguments and Data Gaps sections populated, cross-linked.
- `evergreen` — stable reference material, reviewed by the human, rarely needs substantive change.

Lint flags pages that have not been updated after N new related sources have been ingested — these are candidates for promotion or revision.

### Page Creation Threshold

- **2+ sources** supporting a distinct topic → create a full Concept or Entity page.
- **1 source** only → create a **stub** (minimal frontmatter with `status: seed` plus a single-paragraph overview) rather than a full page.
- **Never leave dead wikilinks**: if you link to a page, ensure that page exists at least as a stub before finishing the edit. Dead links should fail lint.

### Human Verification Gate

- Every AI-created page starts with `explored: false` in frontmatter.
- Only the human sets `explored: true` after reviewing the page.
- The Vault Health dashboard tracks `explored: false` pages so the human can work through the review queue.
- Agents must not flip `explored` to true, even if they subsequently edit the page.

### Counter-arguments and Data Gaps

Every `Concepts/` page includes two mandatory sections:

```markdown
## Counter-arguments

None identified yet.

## Data Gaps

None identified yet.
```

Keep them present even when empty. Their mere presence prompts critical thinking during ingest and query, and makes it obvious when a Concept has been examined adversarially.

### log.md Format

Append entries in this format:

```markdown
## [YYYY-MM-DD] operation | short description

- Affected pages: [[Page A]], [[Page B]]
- Links created: [[Page A]] ↔ [[Page B]]
- Notes: optional one-liner
```

Valid `operation` values:

- `ingest` — a new source was processed.
- `query` — a research question materially changed the vault (new/updated Outputs page, new cross-links).
- `lint` — a maintenance pass fixed issues.
- `update` — a source was revised (see Source Update Workflow) or a page was restructured.

## Skills And Tools

This vault vendors skills under `.agents/skills/`. **Workflows in this file are descriptions of what to do; skills are the triggerable execution paths. Prefer invoking a skill over re-deriving the workflow from prose.**

### Vault-native skills (LLM-triggered workflows)

- **`vault-ingest`** — the Ingest workflow. Triggers on "ingest this", new files in `raw/`, or URL/video handoffs. Full delta check → Sources → Concepts/Entities/Questions → cross-links → index → log → manifest → hot cache.
- **`vault-query`** — the Query workflow. Triggers on research questions against the wiki. Routes via hot.md → index.md → 5-7 synthesized pages, synthesizes with citations, offers to file as an `Outputs/` page.
- **`vault-review`** — walks the `explored: false` queue with LLM judgment. Triggers on "review the queue", "work through pending pages". Approve / contest / mark-duplicate per page.
- **`vault-maintain`** — weekly maintenance. Triggers on "lint", "health check", "clean up". Wraps `bin/vault-health.sh` and adds judgment for orphan/stale/crystallization decisions.
- **`vault-init`** — initialize a new vault from this template.

When performing an ingest, query, review, or maintenance task, invoke the matching skill — do not inline the workflow here.

### Externally-vendored skills

- `agent-browser`: browsing and capturing web sources before filing them into `raw/`.
- `obsidian-markdown`: creating or editing `.md` notes with wikilinks, callouts, embeds, and Obsidian properties.
- `obsidian-bases`: creating or editing `.base` files.
- `json-canvas`: creating or editing `.canvas` files.
- `obsidian-cli`: vault operations, searches, note management, plugin/theme work, and other Obsidian CLI tasks.
- `defuddle`: turning web pages into clean markdown before filing them into the vault.

Tool defaults for this repo:

- If a standard tool for this workflow is missing, first check whether it is installed; if not, install it and then use it.
- `rg` from ripgrep: prefer for fine-tuned search and discovery across the vault. 
- `agent-browser`: prefer for ingesting web content into `raw/`. Install the CLI with `brew install agent-browser`, then run `agent-browser install`.
- When using `agent-browser` for ingest, save durable source artifacts under `raw/` and downloaded attachments under `raw/assets/`.
- `agent-browser` auth state, session exports, and similar browser secrets must stay out of version control.
- `grep`: use for direct pattern matching when simple text search is enough.
- Prefer vault files and existing wiki pages over chat memory.
- Prefer editing existing notes over creating new notes with overlapping scope.
- Prefer `index.md` for navigation at small scale instead of inventing extra retrieval layers.
- If a source includes important images, keep local attachments in `raw/assets/` and reference them from the source workflow rather than leaving them as external URLs when possible.

### yt-dlp Integration

- `yt-dlp`: fetch transcripts and metadata from YouTube and other video sources.
- Use `bin/yt-ingest.sh` as the standard wrapper for the full video-to-raw pipeline.

**Single video workflow:**

```sh
bin/yt-ingest.sh "https://www.youtube.com/watch?v=VIDEO_ID"
```

Under the hood this runs:

```sh
yt-dlp --write-auto-sub --sub-lang en --sub-format vtt --skip-download \
  --write-info-json -o "raw/%(title)s.%(ext)s" "<url>"
```

The wrapper converts the VTT transcript to markdown with YAML frontmatter (title, channel, upload date, URL, duration) and saves it to `raw/`. Timestamps are preserved as section headers for reference-mode navigability.

**Playlist workflow:**

```sh
bin/yt-ingest.sh "https://www.youtube.com/playlist?list=PLAYLIST_ID"
# Optional: cap how many videos to process
bin/yt-ingest.sh "https://www.youtube.com/playlist?list=PLAYLIST_ID" --limit 10
```

The script auto-detects playlist URLs (by the `list=` parameter), lists videos with `--flat-playlist`, then processes each one individually.

**After fetching**, follow the normal Ingest workflow to create wiki pages from the transcript.

**Timestamp preservation:** VTT format retains timestamps. The wrapper converts these into `## [HH:MM:SS]` section headers so that wiki pages can link back to specific moments in the video.

## Claim Provenance and Uncertainty

### Provenance Markers

Every claim on a wiki page carries one of three provenance levels:

- **Extracted** (default): directly stated in a source. No special markup needed.
- **Inferred**: derived by the agent from one or more sources but not explicitly stated. Mark with `> [!info] Inferred` callout.
- **Ambiguous**: the source is unclear or the claim could be read multiple ways. Mark with `> [!warning] Ambiguous` callout.

### Uncertainty Callouts

Use built-in Obsidian callout types for standard situations:

- `> [!info]` — supplementary context, inferred claims
- `> [!question]` — contested claims, open questions
- `> [!warning]` — uncertain or ambiguous claims

Use these custom callout types for research-specific situations:

- `> [!contradiction]` — two or more sources disagree on a factual claim
- `> [!gap]` — an identified gap in the evidence or coverage
- `> [!key-insight]` — a particularly important or non-obvious finding
- `> [!stale]` — a claim that may be outdated due to newer sources

### Confidence Frontmatter

Add a `confidence` field to Concepts/ and Entities/ pages:

- `confidence: high` — well-supported by multiple independent sources
- `confidence: medium` — supported but with limited evidence or some ambiguity
- `confidence: low` — speculative, single-source, or contested

## Recommended Frontmatter Schema

| Page Type | Fields |
|-----------|--------|
| Sources/ | `source_file`, `url`, `date_published`, `date_ingested`, `type` (article / paper / thread / book / video), `explored: false` |
| Concepts/ | `status`, `confidence`, `source_count`, `aliases`, `explored: false` |
| Entities/ | `type` (person / org / product / tool / text), `status`, `aliases`, `explored: false` |
| Questions/ | `status` (open / investigating / resolved), `raised_by` |
| Outputs/ | `query`, `status` (current / superseded), `created` |

All AI-created pages receive `explored: false`. Only the human sets `explored: true` after review. See Human Verification Gate below.