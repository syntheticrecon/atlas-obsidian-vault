---
title: How This Vault Works
---

# How This Vault Works

A complete guide to the research vault — what it is, why it's built this way, and how to use every piece of it.

## Table of Contents

- [Core Concept](#core-concept)
- [Three-Layer Architecture](#three-layer-architecture)
- [Directory Structure](#directory-structure)
- [Page Types](#page-types)
- [The Three Workflows](#the-three-workflows)
- [Frontmatter Schema](#frontmatter-schema)
- [Cross-Linking](#cross-linking)
- [Provenance, Uncertainty, and Confidence](#provenance-uncertainty-and-confidence)
- [Source Conflicts](#source-conflicts)
- [Page Lifecycle](#page-lifecycle)
- [Session Continuity with hot.md](#session-continuity-with-hotmd)
- [Delta Tracking](#delta-tracking)
- [Templates](#templates)
- [Custom Callouts](#custom-callouts)
- [Health Tooling](#health-tooling)
- [Video Ingest with yt-dlp](#video-ingest-with-yt-dlp)
- [Skills and External Tools](#skills-and-external-tools)
- [Spawning New Vaults](#spawning-new-vaults)
- [Scaling Strategy](#scaling-strategy)
- [Common Recipes](#common-recipes)
- [Pitfalls to Avoid](#pitfalls-to-avoid)

---

## Core Concept

This vault is an **LLM-maintained research wiki**. You curate sources and ask questions; the LLM handles all the bookkeeping — summarizing, cross-linking, extracting entities, synthesizing concepts, updating the index, logging operations.

The key insight (from [[methodology/llm-wiki|Karpathy's LLM-wiki pattern]]): **the tedious part of maintaining a knowledge base is not the reading or thinking — it's the bookkeeping**. LLMs don't get bored, can touch 15 files in one pass, and never forget to update the index. Humans abandon traditional wikis because maintenance grows faster than value. LLMs invert that equation.

Think of it as a **compiler**: sources are input, the wiki is compiled output, the LLM is the compiler, `AGENTS.md` is the build configuration.

### Why not RAG?

Traditional RAG retrieves fragments from raw documents on every query. This vault does the opposite: it **incrementally builds a persistent, structured, hand-shaped wiki** as a compiled layer between sources and queries. The wiki compounds — once knowledge is synthesized and cross-linked, it stays that way. Every query can reuse prior synthesis instead of re-deriving it from raw text.

### Why not just let the LLM read raw/ every time?

At scale, that wastes context. A 10KB synthesized concept page is more useful than 100KB of raw source text for most queries. The wiki is the cached, distilled, cross-referenced form.

---

## Three-Layer Architecture

```
┌─────────────────────────────────────┐
│ Layer 3: AGENTS.md (the schema)    │  ← humans and LLM co-evolve this
│ Conventions, workflows, page rules │
├─────────────────────────────────────┤
│ Layer 2: The Wiki                  │  ← LLM-owned, compiled artifact
│ Sources/, Concepts/, Entities/,    │
│ Questions/, Outputs/, index, log   │
├─────────────────────────────────────┤
│ Layer 1: raw/ (source of truth)    │  ← humans curate, immutable
│ Articles, papers, transcripts,     │
│ clippings, images                  │
└─────────────────────────────────────┘
```

**Layer 1 (`raw/`)**: Immutable source documents. Humans drop files here. LLM reads but never edits.

**Layer 2 (the wiki)**: Compiled synthesis. LLM creates, updates, cross-links. Humans read and occasionally steer.

**Layer 3 (`AGENTS.md`)**: The schema that governs Layer 2. Humans and LLM evolve it together as the vault matures. `CLAUDE.md` is a symlink to it.

---

## Directory Structure

```
vault/
├── AGENTS.md                # Agent schema (canonical)
├── CLAUDE.md                # Symlink → AGENTS.md
├── howto.md                 # This file
├── hot.md                   # Session continuity cache
├── index.md                 # Navigation hub
├── log.md                   # Append-only operation log
├── Vault Health.base        # Obsidian Bases dashboard
│
├── raw/                     # Immutable source material
│   ├── assets/              # Images, attachments
│   └── .manifest.json       # Delta tracking (source hashes → wiki pages)
│
├── Sources/                 # One page per ingested source (created on demand)
├── Concepts/                # Synthesized topic pages (created on demand)
├── Entities/                # Named things: people, orgs, products (created on demand)
├── Questions/               # Open questions, contradictions (created on demand)
├── Outputs/                 # Reusable deliverables from queries (created on demand)
│
├── methodology/             # Canonical references about the pattern itself
│   ├── llm-wiki.md
│   └── 2026-04-02T204221.000Z - Thread by @karpathy.md
│
├── _templates/              # Page scaffolds (not wiki content)
│   ├── Source.md
│   ├── Concept.md
│   ├── Entity.md
│   ├── Question.md
│   └── Output.md
│
├── bin/                     # Utility scripts
│   ├── vault-health.sh      # Severity-tiered lint
│   ├── cross-linker.sh      # Find unlinked mentions
│   └── yt-ingest.sh         # yt-dlp wrapper for video sources
│
├── .obsidian/
│   ├── snippets/
│   │   └── wiki-callouts.css    # Custom callout styles
│   └── (standard Obsidian config)
│
├── .agents/skills/          # Vendored agent skills
└── .claude/settings.json    # Claude Code config
```

The wiki content folders (`Sources/`, `Concepts/`, `Entities/`, `Questions/`, `Outputs/`) are **created on demand** during first ingest, not pre-scaffolded. This keeps the template clean and forces the agent to think about structure deliberately.

---

## Page Types

### `Sources/` — one page per ingested source

A summary of a raw document. Contains key claims, concepts extracted, entities mentioned, open questions. Links back to `raw/`. This is where provenance lives.

### `Concepts/` — synthesized topic pages

Ideas, patterns, categories that span multiple sources. *Not proper nouns.* Examples: "Knowledge Compilation", "Staged Autonomy", "Retrieval-Augmented Generation".

Every Concept page has mandatory `## Counter-arguments` and `## Data Gaps` sections — even if empty ("None identified yet."). Their presence prompts critical thinking during synthesis.

### `Entities/` — proper nouns

Specific, fixed-identity things: a person, organization, product, place, tool, or named text. Examples: "Andrej Karpathy", "Obsidian", "Vannevar Bush", "The Bitter Lesson".

**Entity vs Concept heuristic**: if it's a proper noun you'd find in a directory, it's an Entity. If it's an idea you'd find in a glossary, it's a Concept. When in doubt, prefer Concept — promoting a Concept to Entity is easier than splitting an overgrown Entity.

### `Questions/` — open questions and contradictions

Things the sources disagree on, things you don't know yet, investigations in progress. Each Question has a `status` (`open` | `investigating` | `resolved`) and `raised_by` (the source(s) that prompted it).

### `Outputs/` — reusable deliverables

Query answers that are worth keeping. If a question produces a useful synthesis, file it here as an `Outputs/` page so future queries can reference it instead of re-deriving the answer. This is what makes the wiki *compound*.

---

## The Three Workflows

### Ingest — add a new source

When a new source lands in `raw/`:

1. **Delta check**: compute the source's SHA-256. If it matches a `status: current` entry in `raw/.manifest.json`, skip (unless force-ingest is requested).
2. Read the source.
3. Create or update a page in `Sources/`.
4. Extract claims, concepts, entities, open questions.
5. Update existing `Concepts/`, `Entities/`, `Questions/` pages *before* creating new ones (avoid duplicates).
6. Add cross-links between affected pages.
7. Update `index.md` with new entries.
8. Append an entry to `log.md`.
9. Update `raw/.manifest.json` with the source hash and list of wiki pages created/updated.

Default to **one source at a time**, especially early in a new domain. The agent earns autonomy by first establishing the ontology. Only ask clarification questions when the ontology is unclear enough that you'd likely create bad structure.

### Query — answer a research question

1. Read `hot.md` first (session context).
2. Read `index.md` for navigation.
3. Read the most relevant synthesized pages (Concepts/, Entities/, Outputs/) before drilling into Sources/.
4. Limit to 5-7 pages per query round to stay within context.
5. Answer in chat.
6. If the answer is reusable, file it as an `Outputs/` page and link from related pages.
7. If the query materially changed the wiki, append to `log.md`.

### Lint — maintenance pass

Run `bin/vault-health.sh` or ask the agent to do a manual check. Findings are severity-tiered:

**Errors (must fix)**: broken wikilinks, missing required frontmatter, dead links in index.

**Warnings (should address)**: orphaned pages (no inbound links), pages with no outgoing links, stale `confidence: high` claims with newer sources, unresolved contradictions > 30 days old, duplicate pages.

**Info (nice to have)**: pages with `explored: false`, `status: seed` pages with new linked sources, missing `aliases`, unlinked mentions (run `bin/cross-linker.sh`).

---

## Frontmatter Schema

Keep frontmatter light — only add fields that help navigation, provenance, or stable querying. Recommended fields per page type:

| Page Type | Fields |
|-----------|--------|
| `Sources/` | `source_file`, `url`, `date_published`, `date_ingested`, `type` (article / paper / thread / book / video), `explored: false` |
| `Concepts/` | `status`, `confidence`, `source_count`, `aliases`, `explored: false` |
| `Entities/` | `type` (person / org / product / tool / text), `status`, `aliases`, `explored: false` |
| `Questions/` | `status` (open / investigating / resolved), `raised_by` |
| `Outputs/` | `query`, `status` (current / superseded), `created` |

### The `explored` gate

Every AI-created page starts with `explored: false`. Only a human sets it to `true` after reviewing the page. The Vault Health dashboard tracks unreviewed pages so humans can work through the queue.

**Agents must never flip `explored` to true**, even if they subsequently edit the page.

### `aliases` prevents duplicates

Add aliases for every synonym a concept might have:

```yaml
aliases: [ML, statistical learning]
```

Obsidian's wikilink resolution honors aliases, so `[[ML]]` will correctly point to a page titled `Machine Learning`. This is the single biggest defense against ontology drift (the same idea getting two different pages).

---

## Cross-Linking

Links are the value. A vault with 100 pages and 500 links is more useful than one with 1,000 pages and 50 links.

### Rules

- **Bidirectional**: Every `Sources/` page links to the Concepts/Entities it informs; each Concept/Entity links back to its Sources.
- **Questions/ → Sources/Concepts**: Questions link to what raised them; those pages link back to the Question.
- **Inline in prose**: Place wikilinks where the idea appears, not in a link-dump section at the bottom. A small `## Related` section for peripheral links is fine.
- **First-mention-only**: Link a concept the first time it appears on a page. Don't link the same name 5 times.
- **Cross-folder just works**: `[[Page Name]]` resolves from anywhere in the vault.

### Never leave dead wikilinks

If you link to `[[New Concept]]`, that page must exist — at least as a stub — before you save. Dead links fail lint.

**Stub** = minimal frontmatter (`status: seed`) + a one-paragraph overview. Create stubs for concepts that appear in only 1 source. Promote to full pages when a second source arrives.

---

## Provenance, Uncertainty, and Confidence

Every claim on a page has a provenance:

- **Extracted** (default) — directly stated in a source. No special markup needed.
- **Inferred** — derived by the LLM from one or more sources but not explicitly stated. Mark with:
  ```
  > [!info] Inferred
  > Claim and reasoning.
  ```
- **Ambiguous** — the source is unclear or the claim could be read multiple ways:
  ```
  > [!warning] Ambiguous
  > What's unclear.
  ```

### Confidence frontmatter

On Concepts/ and Entities/ pages, add:

```yaml
confidence: high | medium | low
```

- `high` — well-supported by multiple independent sources
- `medium` — supported but with limited evidence or some ambiguity
- `low` — speculative, single-source, or contested

Queryable via Bases (see `Vault Health.base`).

### Callout types cheat sheet

| Callout | Use |
|---------|-----|
| `> [!info]` | Supplementary context, inferred claims |
| `> [!question]` | Contested claims, open questions |
| `> [!warning]` | Uncertain or ambiguous claims |
| `> [!contradiction]` | Two sources disagree on a factual claim |
| `> [!gap]` | Identified gap in evidence or coverage |
| `> [!key-insight]` | Particularly important or non-obvious finding |
| `> [!stale]` | Claim that may be outdated due to newer sources |

The custom callouts (`contradiction`, `gap`, `key-insight`, `stale`) are styled via `.obsidian/snippets/wiki-callouts.css`.

---

## Source Conflicts

When two sources disagree, the first decision is: **supersession** or **contradiction**?

### Supersession — newer data replaces older

The new source reflects updated facts, newer research, or corrected errors.

1. Update the claim on affected Concepts/Entities pages.
2. Mark the old claim with `> [!info] Superseded by [[Newer Source]]`.
3. No `Questions/` page needed.

### Contradiction — genuine peer disagreement

Both sources are roughly equal in authority and recency, but they disagree.

1. Note the conflict on both `Sources/` pages.
2. Create or update a `Questions/` page with `status: open` and `raised_by` pointing to both sources.
3. On affected Concept/Entity pages, wrap the contested claim:
   ```
   > [!contradiction]
   > Source A says X. Source B says Y. See [[Questions/The disputed claim]].
   ```

**Never silently pick one source over another.** If unsure which category applies, treat it as a contradiction.

---

## Page Lifecycle

Every Concept/Entity page moves through:

```
seed → developing → mature → evergreen
```

- `seed` — stub page, 1-2 claims, may exist only to prevent dead wikilinks
- `developing` — multiple sources, synthesis in progress, gaps remain
- `mature` — well-synthesized, Counter-arguments and Data Gaps populated, cross-linked
- `evergreen` — stable reference material, human-reviewed, rarely needs change

Lint flags pages that haven't been updated after N new related sources — candidates for promotion or revision.

### Archival and Deprecation

**Mark, don't delete.** Pages carry institutional memory even when outdated.

- Questions answered by a later source: set `status: resolved`, link to the resolver.
- Concepts/Entities replaced by a refined successor: set `status: superseded`, link to the replacement.
- Outputs whose underlying claims have changed: set `status: superseded`.

The old page remains navigable. Lint passes surface archival candidates but humans confirm.

---

## Session Continuity with hot.md

`hot.md` is a ~500-word cache of what matters *right now*. Sections:

- **Key Facts** — current vault state
- **Recent Changes** — pages created/updated recently
- **Active Threads** — what you're actively researching
- **Pending Review** — pages with `explored: false`

### When to read it

- First thing every session (the agent reads it before anything else)
- After context compaction (when Claude's context gets compressed mid-session)
- When you're not sure what's going on

### When to update it

- After every significant ingest
- After a query that materially changed understanding
- At session end, if the wiki changed

The `Stop` hook in `.claude/settings.json` reminds the agent to update hot.md before ending a session.

---

## Delta Tracking

`raw/.manifest.json` tracks every source that's been ingested:

```json
{
  "version": 1,
  "sources": {
    "raw/paper.md": {
      "sha256": "<hex digest>",
      "ingested_at": "2026-04-14T12:00:00Z",
      "wiki_pages": ["Sources/Paper Title.md", "Concepts/Topic.md"],
      "status": "current"
    }
  }
}
```

Before ingesting, the agent checks the manifest. If the source's hash matches an entry with `status: current`, ingest is skipped (unless force-ingest is requested).

### Status values

- `current` — up to date
- `updated` — re-ingested after source changed
- `superseded` — replaced by a newer version (see Source Update workflow in `AGENTS.md`)

---

## Templates

`_templates/` contains starter scaffolds for each page type. Copy one to the appropriate folder when creating a page, then fill it in.

| Template | Frontmatter includes | Sections |
|----------|---------------------|----------|
| `Source.md` | source_file, url, date_published, date_ingested, type, explored | Summary, Key Claims, Concepts Extracted, Entities Mentioned, Open Questions, Related |
| `Concept.md` | status, confidence, source_count, aliases, explored | Overview, Key Claims, **Counter-arguments**, **Data Gaps**, Sources, Related |
| `Entity.md` | type, status, aliases, explored | Overview, Key Facts, Sources, Related |
| `Question.md` | status, raised_by | Context, Current Understanding, What Would Resolve This, Related |
| `Output.md` | query, status, created | Question, Findings, Methodology, Related |

The Concept template is the only one with mandatory Counter-arguments and Data Gaps sections — those exist by design to force adversarial thinking.

---

## Custom Callouts

Four custom callout types are styled via `.obsidian/snippets/wiki-callouts.css`:

```markdown
> [!contradiction]
> Source A says X. Source B says Y.

> [!gap]
> We don't have data on Z.

> [!key-insight]
> This is the non-obvious finding that matters.

> [!stale]
> This claim was accurate as of 2024 but newer sources contradict it.
```

The snippet is enabled via `.obsidian/appearance.json`. If you use a different Obsidian theme, the colors may need adjustment.

---

## Health Tooling

### `bin/vault-health.sh`

Severity-tiered lint report.

```bash
bin/vault-health.sh               # current directory
bin/vault-health.sh /path/to/vault
```

Checks: broken wikilinks, missing frontmatter, orphaned pages, pages with no outgoing links, `explored: false` pages, seed-status pages, missing aliases.

Runs cleanly on empty vaults (reports "Vault is in template state").

### `bin/cross-linker.sh`

Finds unlinked mentions — cases where a page's name appears in another page but isn't wikilinked.

```bash
bin/cross-linker.sh
```

Skips short names (< 4 chars) to avoid false positives. Run after each ingest to catch missed cross-links.

### `Vault Health.base`

Obsidian Bases dashboard with 8 views:

- All Wiki Pages
- Needs Human Review (`explored: false`)
- By Status (seed/developing/mature/evergreen)
- By Type (Source/Concept/Entity/Question/Output)
- By Folder
- High Confidence Claims (flag for staleness)
- Seed Pages (candidates for promotion)
- Open Questions

Open it in Obsidian as a live dashboard.

---

## Video Ingest with yt-dlp

The `bin/yt-ingest.sh` wrapper turns YouTube videos into `raw/` markdown files with timestamps preserved as section headers.

### Install yt-dlp first

```bash
brew install yt-dlp
```

### Single video

```bash
bin/yt-ingest.sh "https://www.youtube.com/watch?v=VIDEO_ID"
```

Output: `raw/slugified-title.md` with YAML frontmatter (title, channel, upload_date, url, duration) and the transcript body. Timestamps appear as `## [HH:MM:SS]` section headers so wiki pages can link back to specific moments.

### Playlist

```bash
bin/yt-ingest.sh "https://www.youtube.com/playlist?list=PLAYLIST_ID"
bin/yt-ingest.sh "https://...?list=..." --limit 10  # cap processing
```

The script auto-detects playlists from the `list=` URL parameter. Each video becomes its own markdown file in `raw/`.

After fetching, run the normal Ingest workflow to create wiki pages from each transcript.

---

## Skills and External Tools

Vendored skills (in `.agents/skills/`, tracked in `skills-lock.json`):

| Skill | Use |
|-------|-----|
| `agent-browser` | Capturing web sources before filing into `raw/` |
| `defuddle` | Cleaning web pages into markdown before filing |
| `obsidian-markdown` | Creating/editing `.md` notes with wikilinks, callouts, embeds, properties |
| `obsidian-bases` | Creating/editing `.base` files |
| `obsidian-cli` | Vault operations, searches, plugin work |
| `json-canvas` | Creating/editing `.canvas` files |
| `vault-init` | Spawning new vaults from this template |

External tools expected (install if missing):

- `rg` (ripgrep) — fine-tuned search across the vault
- `yt-dlp` — video/YouTube transcripts
- `agent-browser` — `brew install agent-browser` then `agent-browser install`
- `defuddle` — web page → clean markdown

Browser auth state, session exports, and similar secrets must stay out of version control (already covered in `.gitignore`).

---

## Spawning New Vaults

The `vault-init` skill scaffolds new vaults from this template.

```bash
.agents/skills/vault-init/vault-init.sh /path/to/new-vault
```

Creates a vault with:

- `.obsidian/` config (including callouts CSS snippet)
- `_templates/` with all 5 templates
- `bin/` scripts (executable)
- `methodology/` reference docs
- `raw/assets/` + manifest
- `AGENTS.md` + `CLAUDE.md` symlink
- `hot.md`, `index.md`, `log.md`, `Vault Health.base`

Wiki content folders are *not* pre-created — they materialize on first ingest.

What's not copied: `.claude/settings.json` (each project owns its own) and `skills-lock.json` (each vault manages its own skills).

---

## Scaling Strategy

Match your index and tooling to vault size:

| Vault size | Index format | Tooling |
|------------|--------------|---------|
| 0-20 pages | Flat list per folder | None extra |
| 20-50 pages | Flat list + one-line descriptions | None extra |
| 50-100 pages | Grouped by subtopic within each folder | Start using Bases dashboard |
| 100-300 pages | Maps of Content (MOC) pattern — topic indexes that `index.md` links to | Consider `qmd` for local search |
| 300+ pages | MOCs + `qmd` or hybrid search | Consider external graph export |

Graduate to the next tier only when the current one starts to feel unwieldy. Don't over-engineer early.

---

## Common Recipes

### Ingest a web article

1. Use `defuddle` or `agent-browser` to save clean markdown into `raw/`.
2. Store attachments (images referenced by the article) in `raw/assets/`.
3. Ask the agent to "ingest the source at raw/Article Title.md".
4. Review the Sources/ page and any new Concept/Entity pages. Set `explored: true` where satisfied.

### Ingest a YouTube talk

1. `bin/yt-ingest.sh "https://youtube.com/watch?v=..."`
2. Ask the agent to ingest the resulting `raw/<slug>.md`.
3. Reference timestamps by their `## [HH:MM:SS]` section headers in the Sources/ page.

### Research question

1. Ask the agent a question (e.g., "what do my sources say about staged autonomy?").
2. It reads `hot.md`, then `index.md`, then 5-7 relevant pages.
3. It answers in chat.
4. If the answer is reusable, ask "file this as an Output" — it creates an `Outputs/` page and links related pages.

### Weekly maintenance

1. `bin/vault-health.sh`
2. `bin/cross-linker.sh`
3. Open `Vault Health.base` — work through "Needs Human Review".
4. Resolve any contradictions older than 30 days.
5. Promote `seed` pages that now have 2+ sources.

### Updating `hot.md` after a big session

Ask the agent: "update hot.md with what changed this session". It should rewrite (not append) to keep it under ~500 words.

---

## Pitfalls to Avoid

### Hallucination in synthesis

Top LLMs hallucinate 10-20% of claims in adversarial testing. **Every claim should trace to a source page, and every source page should trace to `raw/`.** Run lint regularly to catch drift.

### Ontology drift

Without `aliases`, the same concept gets two pages — "Machine Learning" and "ML" and "Statistical Learning". Always add synonyms to frontmatter. When reviewing an AI-created Concept, ask: "could this be a duplicate of an existing page?"

### Duplicate pages

The Ingest workflow says "update existing pages before creating new ones". If the agent creates parallel pages, merge them and add aliases. Lint for overlapping scope periodically.

### Link rot

External URLs decay. For important sources, download assets locally to `raw/assets/`. For web captures, use `defuddle` or `agent-browser` to save the content, not just the URL.

### Losing understanding

Outsourcing bookkeeping risks building a reference without internalizing anything. Stay in the loop during ingest for the first 20-50 sources — review what the agent writes, correct bad synthesis, steer the ontology. The agent earns autonomy by proving it's internalized your patterns.

### Over-linking vs under-linking

Don't link the same concept 5 times on a page (first-mention-only). Don't leave pages without outgoing links (they become dead ends). Run `bin/cross-linker.sh` to find unlinked mentions.

### Stale `confidence: high` claims

A page marked `confidence: high` when newer sources contradict it is worse than a page marked `low`. Lint flags these — promote to mature/evergreen only after human review.

### Premature archival

Don't set `status: superseded` on a page just because a newer source arrived — apply the Source Conflict workflow first. Supersession is for factual updates; contradiction is for peer disagreement.

---

## Philosophical Notes

### Staged autonomy

The LLM doesn't start with full autonomy. Early in a domain, humans review every ingested source and every created page — this is how the ontology gets established. As patterns stabilize, the agent handles more on its own. The `explored: false` flag is the visible marker of this trust curve.

### The wiki is the compiler's output

You shouldn't edit wiki pages by hand except occasionally — and when you do, the agent should see your edits on the next pass and reconcile them with the schema. If you find yourself fighting the wiki, update `AGENTS.md` to encode what you want instead. The schema is the control knob.

### Compounding, not accumulating

The goal isn't to accumulate notes. It's to build a knowledge base where every new source strengthens existing pages (new sources confirm claims, raise confidence, close gaps) and every query that materially helps gets filed back as an `Outputs/` page others can reuse. A page you wrote 6 months ago should be *more* useful today, not less.

### Prefer fewer, denser pages

A mature Concept page with 500 words synthesizing 10 sources beats 10 stub pages with 50 words each. Push toward synthesis, not catalogs.

---

## Daily / Weekly Rhythm

The vault compounds because of a rhythm, not just structure. Build the habit:

**Every session**:
- Agent reads `hot.md` first to restore context
- After any wiki change, the agent updates `hot.md` (Stop hook reminds you)

**After each ingest**:
- Run `bin/review.sh` to walk the `explored: false` queue — approve, skip, contest, or edit
- Watch for the moment the LLM "gets" your ontology; that's when autonomy widens

**Weekly**:
- `bin/stats.sh` — see page counts, status distribution, link density, review velocity
- `bin/vault-health.sh` — severity-tiered lint
- `bin/cross-linker.sh` — scan for unlinked mentions
- Promote mature Concepts (status: mature → evergreen if stable)
- Resolve or escalate contradictions older than 30 days

**When the wiki feels unwieldy** (roughly at 50+ pages):
- Graduate `index.md` to the next tier (see Index Scaling Strategy in AGENTS.md)
- Consider installing `qmd` for local search

## Quick Reference

- **First time?** Run `bin/quickstart.sh` for a guided walkthrough
- **Read first each session**: `hot.md` → `index.md` → specific pages
- **After ingest**: update `index.md`, `log.md`, `raw/.manifest.json`, `hot.md`
- **Mandatory on Concepts/**: `## Counter-arguments`, `## Data Gaps` sections
- **Callout for contradictions**: `> [!contradiction]` (custom, styled)
- **Human-only frontmatter flip**: `explored: false → true`
- **Lint before wiki grows wild**: `bin/vault-health.sh`
- **Find missed links**: `bin/cross-linker.sh`
- **Video to raw**: `bin/yt-ingest.sh <url>`
- **Review queue**: `bin/review.sh` (interactive) or `bin/review.sh --list`
- **Metrics**: `bin/stats.sh`
- **Quickstart**: `bin/quickstart.sh`
- **New vault**: `.agents/skills/vault-init/vault-init.sh <path>`

For deeper detail on any workflow, read [[AGENTS|AGENTS.md]] — it's the canonical schema.
