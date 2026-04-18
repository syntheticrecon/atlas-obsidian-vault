---
title: Tutorial
---

# Tutorial

A complete guide to this LLM-maintained research vault — what it is, why it's built this way, and how to use every piece of it.

> [!tip] Just cloned the template?
> Run `bin/quickstart.sh` for a 5-minute walkthrough, then come back here for depth.

## Contents

- [The idea in one paragraph](#the-idea-in-one-paragraph)
- [Architecture](#architecture)
- [What's in the vault](#whats-in-the-vault)
- [The five skills](#the-five-skills)
- [Page types](#page-types)
- [Frontmatter schema](#frontmatter-schema)
- [The three workflows](#the-three-workflows)
- [Cross-linking rules](#cross-linking-rules)
- [Provenance, uncertainty, confidence](#provenance-uncertainty-confidence)
- [Source conflicts](#source-conflicts)
- [Page lifecycle](#page-lifecycle)
- [Session continuity: `hot.md`](#session-continuity-hotmd)
- [Delta tracking: `raw/.manifest.json`](#delta-tracking-rawmanifestjson)
- [Custom callouts](#custom-callouts)
- [Utility scripts in `bin/`](#utility-scripts-in-bin)
- [Video ingest with `yt-dlp`](#video-ingest-with-yt-dlp)
- [Starting a new vault](#starting-a-new-vault)
- [Daily and weekly rhythm](#daily-and-weekly-rhythm)
- [Scaling strategy](#scaling-strategy)
- [Pitfalls to avoid](#pitfalls-to-avoid)
- [Philosophy](#philosophy)
- [Quick reference card](#quick-reference-card)

---

## The idea in one paragraph

You curate sources. You ask questions. The LLM handles the bookkeeping — summarizing, extracting entities, cross-linking, updating the index and log, reconciling contradictions. The wiki is a persistent compiled artifact that lives in your vault as markdown. It compounds over time: new sources strengthen existing pages, query answers get filed back as permanent pages, and six months from now a page you wrote today is *more* useful because it's been reinforced by everything since. [Karpathy's LLM-wiki pattern](methodology/llm-wiki.md) calls this *"wiki as compiler"* — raw sources are input, markdown is compiled output, the LLM is the compiler, `AGENTS.md` is the build config.

> [!key-insight]
> The tedious part of maintaining a knowledge base isn't reading or thinking — it's bookkeeping. Humans abandon wikis because maintenance grows faster than value. LLMs don't experience tedium, so that equation inverts.

---

## Architecture

Three layers, clearly separated:

```
┌────────────────────────────────────────────┐
│  Layer 3 — Schema  (AGENTS.md)             │  ← humans + LLM co-evolve
│  Rules, workflows, page conventions        │
├────────────────────────────────────────────┤
│  Layer 2 — Wiki  (Sources/Concepts/...)    │  ← LLM-owned compiled artifact
│  Summaries, synthesis, cross-links         │
├────────────────────────────────────────────┤
│  Layer 1 — Raw  (raw/)                     │  ← humans curate, immutable
│  Articles, papers, transcripts, images     │
└────────────────────────────────────────────┘
```

- **`raw/`** — immutable source documents. Humans drop files here. The LLM reads but never edits.
- **Wiki** — compiled synthesis. The LLM creates and updates. Humans read and occasionally steer.
- **`AGENTS.md`** — the schema that governs everything. Co-evolved between human and LLM. `CLAUDE.md` is a symlink to it, so Claude Code discovers it automatically.

---

## What's in the vault

```
vault-root/
├── AGENTS.md                     ← agent-facing schema (canonical)
├── CLAUDE.md                     ← symlink → AGENTS.md
├── TUTORIAL.md                   ← this file (human-facing)
├── README.md                     ← GitHub landing page
├── hot.md                        ← session continuity cache (~500 words)
├── index.md                      ← navigation hub
├── log.md                        ← append-only operation log
├── Vault Health.base             ← Obsidian Bases dashboard (8 views)
│
├── raw/
│   ├── assets/                   ← images and attachments for sources
│   └── .manifest.json            ← SHA-based delta tracking of ingested sources
│
├── Sources/                      ← one page per ingested source       } created on
├── Concepts/                     ← synthesized topic pages             } demand during
├── Entities/                     ← named things (person/org/product)   } first ingest,
├── Questions/                    ← open questions, contradictions      } not pre-
├── Outputs/                      ← reusable deliverables from queries  } scaffolded
│
├── _templates/                   ← page scaffolds (used by Obsidian Templates core plugin)
│   ├── Source.md
│   ├── Concept.md
│   ├── Entity.md
│   ├── Question.md
│   ├── Output.md
│   └── sample-source.md          ← fixture for your first ingest
│
├── methodology/                  ← reference docs linking to originals
│   ├── llm-wiki.md               ← Karpathy's LLM-wiki gist
│   ├── karpathy-thread.md        ← Karpathy's X thread on knowledge bases
│   └── obsidian-skills.md        ← kepano's obsidian-skills repo
│
├── bin/                          ← utility scripts (all executable)
│   ├── quickstart.sh             ← 5-step first-run walkthrough
│   ├── vault-health.sh           ← severity-tiered lint (errors/warnings/info)
│   ├── cross-linker.sh           ← find unlinked mentions of known pages
│   ├── stats.sh                  ← page counts, status distribution, link density
│   ├── review.sh                 ← walk the `explored: false` queue (bash menu)
│   └── yt-ingest.sh              ← yt-dlp wrapper (single video + playlist)
│
├── tests/                        ← test suite (optional, for template maintainers)
│   ├── test.sh                   ← master orchestrator
│   ├── lint/                     ← static + schema validation (Python, bash)
│   ├── schemas/                  ← JSON schemas for manifest, settings, frontmatter
│   ├── integration/              ← bats end-to-end tests
│   └── fixtures/                 ← test fixtures
│
├── .obsidian/
│   ├── app.json, core-plugins.json, community-plugins.json, graph.json
│   ├── appearance.json           ← enables the wiki-callouts CSS snippet
│   ├── templates.json            ← points Templates plugin at `_templates/`
│   ├── snippets/wiki-callouts.css   ← styles for contradiction/gap/key-insight/stale
│   └── plugins/OA-file-hider/    ← File Hider plugin (pre-configured)
│
├── .agents/skills/               ← agent-neutral skill source of truth
│   ├── vault-ingest/             ← ingest workflow skill
│   ├── vault-query/              ← query workflow skill
│   ├── vault-review/             ← review workflow skill
│   ├── vault-maintain/           ← maintenance workflow skill
│   ├── vault-init/               ← new-vault scaffolding skill
│   └── (agent-browser, defuddle, obsidian-*, json-canvas)
│
└── .claude/
    ├── skills/                   ← symlinks to ../../.agents/skills/* (Claude Code auto-discovery)
    └── settings.json             ← hooks config (Stop: remind to update hot.md)
```

> [!info]
> Wiki content folders (Sources/, Concepts/, Entities/, Questions/, Outputs/) are **created on demand** during first ingest. The template ships without them so a fresh clone is truly empty — no template author's research leaking through.

---

## The five skills

This template ships five vault-native skills that the LLM invokes by natural language. Each has a clear trigger phrase and defined workflow. You say what you want; the skill routes execution.

| Skill | Trigger phrases | What it does |
|-------|-----------------|--------------|
| **`vault-ingest`** | "ingest this source", "process this article", new file in `raw/` | Delta check → create Sources page → extract Concepts/Entities/Questions → cross-link → update index, log, hot cache, manifest |
| **`vault-query`** | "what do my sources say about X?", "summarize Y", "where do they disagree?" | Read hot → index → 5-7 synthesized pages → synthesize with citations → offer to file as Output |
| **`vault-review`** | "review the queue", "work through pending pages" | Walk `explored: false` queue with LLM judgment (approve / contest / mark-duplicate / edit) |
| **`vault-maintain`** | "lint the wiki", "health check", "clean up", "crystallize" | Run health checks → promote seed pages → crystallize mature Outputs → archive stale content |
| **`vault-init`** | "create a new vault" | Duplicate the template to a new path with defensive cleanup |

The skills live at `.agents/skills/vault-*/SKILL.md`. Claude Code auto-discovers them via symlinks in `.claude/skills/`.

> [!tip]
> Read a skill's SKILL.md to understand what it will do. Each one explicitly lists when to use, when NOT to use, the step-by-step workflow, and anti-patterns.

---

## Page types

### `Sources/` — one page per ingested source

Summary of a raw document. Lives alongside the raw file and links back to it. Contains key claims, concepts extracted, entities mentioned, open questions raised. This is where provenance lives: every substantive claim on Concept/Entity pages should ultimately trace to a Sources/ page, which traces to `raw/`.

### `Concepts/` — synthesized topic pages

Ideas, patterns, categories that span multiple sources. **Not proper nouns.** Examples: "Knowledge Compilation", "Staged Autonomy", "Retrieval-Augmented Generation."

Every Concept page has two mandatory sections — `## Counter-arguments` and `## Data Gaps` — even if they say "None identified yet." Their presence forces adversarial thinking during synthesis.

### `Entities/` — proper nouns

Specific, fixed-identity things: a person, organization, product, place, tool, or named text. Examples: "Andrej Karpathy", "Obsidian", "The Bitter Lesson."

> [!info] Entity vs Concept heuristic
> If it's a proper noun you'd find in a directory, it's an Entity. If it's an idea you'd find in a glossary, it's a Concept. When in doubt, prefer Concept — promoting a Concept to Entity later is easier than splitting an overgrown Entity.

### `Questions/` — open questions and contradictions

Things sources disagree on, things you don't know yet, investigations in progress. Each Question has:

- `status`: `open` | `investigating` | `resolved`
- `raised_by`: link(s) to the source(s) that prompted the question

### `Outputs/` — reusable deliverables

Query answers worth keeping. When a research question produces useful synthesis, it's filed here as a page. Future queries read the filed answer instead of re-deriving it. **This is the compounding mechanism.**

---

## Frontmatter schema

Keep frontmatter light — only fields that help navigation, provenance, or stable querying.

| Page type | Required fields | Optional fields |
|-----------|-----------------|-----------------|
| `Sources/` | `type`, `explored` | `source_file`, `url`, `date_published`, `date_ingested` |
| `Concepts/` | `status`, `confidence`, `explored` | `source_count`, `aliases` |
| `Entities/` | `type`, `status`, `explored` | `aliases` |
| `Questions/` | `status` | `raised_by` |
| `Outputs/` | `status` | `query`, `created` |

### Canonical values

| Field | Values |
|-------|--------|
| Source `type` | `article` \| `paper` \| `thread` \| `book` \| `video` |
| Entity `type` | `person` \| `org` \| `product` \| `tool` \| `text` |
| Concept/Entity `status` | `seed` \| `developing` \| `mature` \| `evergreen` \| `superseded` |
| Question `status` | `open` \| `investigating` \| `resolved` |
| Output `status` | `current` \| `superseded` |
| `confidence` | `high` \| `medium` \| `low` |
| `explored` | `false` (AI-created) → `true` (human-reviewed) |

> [!warning] The `explored` gate is sacred
> Agents must never flip `explored` from `false` to `true`, even when they edit a page. Only humans mark a page as reviewed. The review queue depends on this invariant.

### Aliases prevent duplicates

Every synonym a concept might have goes in `aliases:`

```yaml
aliases: [ML, statistical learning, machine learning]
```

Obsidian's wikilink resolution honors aliases — `[[ML]]` in any page correctly links to `Machine Learning`. This is the single biggest defense against ontology drift (the same idea getting two different pages).

---

## The three workflows

### Ingest — add a new source

Triggered by: you say "ingest this source" or drop a new file into `raw/`. The `vault-ingest` skill executes:

1. **Delta check** — compute the source's SHA-256. If `raw/.manifest.json` already has a `status: current` entry with that hash, skip (unless force-ingest requested).
2. **Read** the source.
3. **Create or update** a `Sources/<Title>.md` page from `_templates/Source.md`.
4. **Extract** claims, concepts, entities, open questions.
5. **Update existing pages before creating new ones** — search by title and by `aliases:`. Avoid duplicates.
6. **Cross-link bidirectionally** — Sources ↔ Concepts ↔ Entities. Questions → their source.
7. **Update `index.md`** with new page entries.
8. **Append a log entry**: `## [YYYY-MM-DD] ingest | <Source Title>`.
9. **Update `raw/.manifest.json`** with the SHA and list of wiki pages.
10. **Update `hot.md`** — Recent Changes, Active Threads, Pending Review.

> [!info] Default: one source at a time
> Especially early in a new domain. The agent earns autonomy by first establishing your ontology. Only ask clarification questions when the ontology is unclear enough that you'd likely create bad structure.

### Query — answer a research question

Triggered by: "what do my sources say about X?", "summarize Y", "where do they disagree?". The `vault-query` skill executes:

1. Read `hot.md` (session context).
2. Read `index.md` (navigation).
3. Route to the most relevant **synthesized** pages first (Concepts/, Entities/, Outputs/) before drilling into Sources/.
4. **Limit to 5-7 pages per round** — narrow the question or iterate rather than loading too much.
5. Answer in chat with citations (every substantive claim links to its source).
6. If the answer is reusable, create an `Outputs/<Title>.md` page from `_templates/Output.md` and link related pages.
7. If the query materially changed the wiki, append to `log.md`.

### Lint — maintenance pass

Triggered by: "lint the wiki", "health check", "clean up". The `vault-maintain` skill runs `bin/vault-health.sh` then applies judgment:

| Tier | Checks |
|------|--------|
| **Errors** | Broken wikilinks, missing required frontmatter, dead links in index |
| **Warnings** | Orphaned pages, pages with no outgoing links, stale `confidence: high` claims, unresolved contradictions > 30 days old, duplicate pages |
| **Info** | `explored: false` pages, `status: seed` pages with 2+ new linked sources, missing `aliases`, unlinked mentions |

Also considers: crystallization candidates (Outputs referenced 2+ times → promote insights into Concepts), lifecycle promotions (`seed → developing → mature → evergreen`), archival candidates (mark as `superseded`/`resolved`, never delete).

---

## Cross-linking rules

Links are the value. A vault with 100 pages and 500 links is more useful than one with 1,000 pages and 50 links.

- **Bidirectional**: Every `Sources/` page links to the Concepts/Entities it informs; each Concept/Entity links back to its Sources.
- **Questions ↔ origins**: Questions link to the Sources/Concepts that raised them; those pages link back.
- **Inline in prose**: Place wikilinks where the idea appears, not in a link-dump at the bottom. A small `## Related` section for peripheral links is fine.
- **First-mention-only**: Link a concept the first time it appears on a page. Don't link the same name 5 times.
- **Cross-folder just works**: `[[Page Name]]` resolves from anywhere in the vault.

> [!warning] Never leave dead wikilinks
> If you link to `[[New Concept]]`, that page must exist — at least as a stub — before you save.
>
> A **stub** is minimal frontmatter (`status: seed`) plus a one-paragraph overview. Create stubs for concepts that appear in only 1 source. Promote to full pages when a second source arrives.

---

## Provenance, uncertainty, confidence

Three provenance levels for any claim:

| Level | When | Markup |
|-------|------|--------|
| **Extracted** | Directly stated in a source | (default, no markup) |
| **Inferred** | LLM synthesis — derived but not stated | `> [!info] Inferred`<br>`> Claim and reasoning.` |
| **Ambiguous** | Source is unclear or claim could be read multiple ways | `> [!warning] Ambiguous`<br>`> What's unclear.` |

### Confidence on Concepts and Entities

```yaml
confidence: high      # well-supported by multiple independent sources
confidence: medium    # supported but limited evidence or some ambiguity
confidence: low       # speculative, single-source, or contested
```

Queryable via Bases (open `Vault Health.base`, see the "High Confidence Claims" view).

---

## Source conflicts

When two sources disagree, the first decision is: **supersession** or **contradiction**?

### Supersession — newer replaces older

Updated facts, newer research, corrected errors.

1. Update the claim on affected Concepts/Entities pages.
2. Mark the old version with `> [!info] Superseded by [[Newer Source]]`.
3. No `Questions/` page needed.

### Contradiction — genuine peer disagreement

Both sources are roughly equal in authority and recency.

1. Note the conflict on both `Sources/` pages.
2. Create or update a `Questions/` page with `status: open` and `raised_by` pointing to both sources.
3. On affected Concept/Entity pages, wrap the contested claim:
   ```markdown
   > [!contradiction]
   > Source A says X. Source B says Y. See [[Questions/The disputed claim]].
   ```

> [!warning]
> Never silently pick one source over another. If unsure which category applies, treat it as a contradiction.

---

## Page lifecycle

Every Concept and Entity page moves through stages:

```
seed → developing → mature → evergreen
                              │
                              └──→ superseded  (mark, don't delete)
```

| Status | Meaning |
|--------|---------|
| `seed` | Stub, 1–2 claims, may exist only to prevent dead wikilinks |
| `developing` | Multiple sources, synthesis in progress, gaps remain |
| `mature` | Well-synthesized; Counter-arguments and Data Gaps populated; cross-linked |
| `evergreen` | Stable reference material, human-reviewed, rarely changes |
| `superseded` | Replaced by a refined successor; links to replacement; stays navigable |

> [!info] Mark, don't delete
> Superseded pages carry institutional memory. They remain navigable as history. Lint surfaces archival candidates but humans confirm.

---

## Session continuity: `hot.md`

A ~500-word cache of what matters *right now*.

```
## Key Facts        ← current vault state, skills available, tools installed
## Recent Changes   ← pages created/updated recently
## Active Threads   ← what you're actively researching
## Pending Review   ← pages with `explored: false`
```

**Read it**: first thing every session, after context compaction, when lost.
**Update it**: after any significant ingest, after a materially-changed query, at session end.

The `Stop` hook in `.claude/settings.json` echoes a reminder to update `hot.md` before ending.

---

## Delta tracking: `raw/.manifest.json`

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

Before ingesting, the agent computes the source's SHA and checks the manifest. Match → skip. Miss or force-ingest → proceed.

| `status` | Meaning |
|----------|---------|
| `current` | Up to date |
| `updated` | Re-ingested after source changed |
| `superseded` | Replaced by a newer version (see Source Update workflow in AGENTS.md) |

---

## Custom callouts

Four project-specific callout types are defined in `.obsidian/snippets/wiki-callouts.css` and enabled in `.obsidian/appearance.json`:

| Callout | Visual | Use for |
|---------|--------|---------|
| `> [!contradiction]` | red, ⚔ icon | Two sources disagree on a factual claim |
| `> [!gap]` | amber, ? icon | Identified gap in evidence or coverage |
| `> [!key-insight]` | blue, 💡 icon | Particularly important or non-obvious finding |
| `> [!stale]` | gray, ⏱ icon | Claim may be outdated due to newer sources |

Built-in Obsidian callouts (`info`, `warning`, `question`, `note`, etc.) work as usual.

> [!info]
> The `check-callouts.py` test enforces that every custom callout used in any `.md` file has a matching CSS rule. You can't silently introduce a new callout without adding styling.

---

## Utility scripts in `bin/`

All scripts are executable and run from the vault root.

| Script | Purpose | Usage |
|--------|---------|-------|
| `quickstart.sh` | 5-step first-run walkthrough (prints; non-interactive) | `bin/quickstart.sh` |
| `vault-health.sh` | Severity-tiered lint (errors / warnings / info) | `bin/vault-health.sh [vault-path]` |
| `cross-linker.sh` | Find unlinked mentions of known pages (skips names < 4 chars) | `bin/cross-linker.sh [vault-path]` |
| `stats.sh` | Page counts, lifecycle distribution, review velocity, link density, log summary | `bin/stats.sh [vault-path]` |
| `review.sh` | Walk the `explored: false` queue interactively (bash menu) or `--list` / `--count` | `bin/review.sh` / `--list` / `--count` |
| `yt-ingest.sh` | yt-dlp wrapper: transcript + metadata to `raw/` with timestamps as section headers | `bin/yt-ingest.sh <url> [--limit N]` |

> [!tip]
> `review.sh` is a bash fallback for fast menu-driven approvals. For more thoughtful review with LLM judgment (duplicate detection, evidence scrutiny), ask the agent directly: *"walk the review queue."* That invokes the `vault-review` skill.

### Vault Health dashboard

Open `Vault Health.base` in Obsidian. Eight views powered by Obsidian Bases:

1. **All Wiki Pages** — name, type, status, confidence, explored, mtime
2. **Needs Human Review** — filtered to `explored: false`
3. **By Status** — grouped by lifecycle value
4. **By Type** — grouped by folder/type
5. **By Folder** — alternative grouping
6. **High Confidence Claims** — `confidence == high`, useful for staleness check
7. **Seed Pages** — candidates for promotion
8. **Open Questions** — Questions pages with `status: open`

---

## Video ingest with `yt-dlp`

Install: `brew install yt-dlp`

### Single video

```bash
bin/yt-ingest.sh "https://www.youtube.com/watch?v=VIDEO_ID"
```

Creates `raw/<slugified-title>.md` with YAML frontmatter (`title`, `channel`, `upload_date` as YYYY-MM-DD, `url`, `duration` as H:MM:SS, `video_id`) and the transcript body. Timestamps are preserved as `## [HH:MM:SS]` section headers so wiki pages can link back to specific moments.

### Playlist

```bash
bin/yt-ingest.sh "https://www.youtube.com/playlist?list=PLAYLIST_ID"
bin/yt-ingest.sh "https://...?list=..." --limit 10    # cap processing
```

Auto-detects playlists (URL contains `list=`). Each video becomes its own file in `raw/`.

After fetching, invoke the ingest workflow: say *"ingest the new sources in raw/"* and `vault-ingest` takes each file one at a time.

---

## Starting a new vault

Two paths, same result:

### Path A: `git clone` (recommended if you want upstream history)

```bash
git clone https://github.com/<you>/<repo>.git my-vault
cd my-vault
rm -rf .git && git init && git add . && git commit -m "Initial vault"
bin/quickstart.sh
```

### Path B: `vault-init.sh`

```bash
/path/to/template/.agents/skills/vault-init/vault-init.sh ~/research/my-vault
cd ~/research/my-vault
bin/quickstart.sh
```

`vault-init.sh` does `cp -r` on the template, then defensively clears per-session files:

- Wiki content folders (Sources/, Concepts/, etc. — create-on-demand)
- `.claude/settings.local.json` (your permission allowlist from the template session)
- `.git/` (new vault owns its own history)
- Residual entries in `raw/.manifest.json` (reset to empty)

### Next: customize for your domain

Open `AGENTS.md`, find the **Domain Customization** section near the top, and edit it for your research domain:

- ML papers? Add `arxiv_id`, `authors`, `venue` to the Source frontmatter schema
- Recipes? Drop `Questions/` entirely, add `Ingredients/` and `Techniques/`
- Code docs? Add `Decisions/` for architecture decision records
- Biology? Entity subtypes like `species / gene / protein / pathway`

The schema is meant to be co-evolved. Start generic, specialize as the domain reveals itself.

---

## Daily and weekly rhythm

The vault compounds because of a **rhythm**, not just structure. Build the habit:

### Every session

- Agent reads `hot.md` first — you don't need to prompt this
- After any wiki change, agent updates `hot.md`

### After each ingest

- Invoke `vault-review` (say *"review the queue"*) or run `bin/review.sh`
- Approve good pages; flag mistakes with a contest note; correct bad synthesis
- Watch for the moment the LLM "gets" your ontology — that's when autonomy can widen

### Weekly

- `bin/stats.sh` — are counts growing? is review velocity keeping pace?
- `bin/vault-health.sh` — errors and warnings
- `bin/cross-linker.sh` — unlinked mentions
- Or just ask: *"maintain the wiki"* — `vault-maintain` does all three with judgment
- Promote mature Concepts to `evergreen` if stable
- Resolve or escalate contradictions older than 30 days

### When the wiki feels unwieldy (~50+ pages)

- Graduate `index.md` format to the next tier (see [Scaling strategy](#scaling-strategy) below)
- Consider installing `qmd` for local search

---

## Scaling strategy

Match index format and tooling to vault size.

| Pages | Index format | Tooling |
|-------|--------------|---------|
| 0–20 | Flat list per folder | None extra |
| 20–50 | Flat list + one-line descriptions | None extra |
| 50–100 | Grouped by subtopic within each folder | Bases dashboard |
| 100–300 | Maps of Content (MOC) pattern — topic index pages that `index.md` links to | Consider `qmd` for local search |
| 300+ | MOCs + hybrid search | External graph export, possibly a DB-backed index |

**Graduate only when the current tier feels unwieldy.** Don't over-engineer early. The Karpathy thread explicitly notes ~100 articles + ~400K words works fine with manual index files.

---

## Pitfalls to avoid

### Hallucination in synthesis

Top LLMs hallucinate 10–20% of claims in adversarial testing. Defense: every claim traces to a source page; every source page traces to `raw/`. Run `vault-health.sh` regularly. If you read a Concept page and can't find citations, the synthesis isn't trustworthy.

### Ontology drift

Without `aliases:`, the same idea gets two pages — "Machine Learning", "ML", "Statistical Learning". During review, always ask: *"could this be a duplicate of an existing page?"* Use the `vault-review` duplicate-merge action aggressively in the first 50 ingests.

### Duplicate pages

The ingest workflow says "update existing before create." If the agent slips up, merge the pages and add aliases. Lint periodically for overlapping scope.

### Link rot

External URLs decay. For important sources, download assets locally into `raw/assets/`. For web captures, use `defuddle` or `agent-browser` to save the content body, not just the URL.

### Losing understanding

Outsourcing bookkeeping risks building reference material without internalizing anything. Stay in the loop for the first 20–50 sources — review every page, correct bad synthesis, steer the ontology. The agent earns autonomy by proving it internalized your patterns.

### Over- or under-linking

- Over-link: same concept linked 5 times on one page → use first-mention-only
- Under-link: pages with zero outgoing wikilinks → dead ends
- Missed links: unlinked mentions of known pages → run `cross-linker.sh`

### Stale `confidence: high`

A page marked `confidence: high` that newer sources contradict is worse than one marked `low`. During maintenance, review high-confidence pages when new sources land.

### Premature archival

Don't mark a page `superseded` just because a newer source arrived. Apply the Source Conflict workflow first. Supersession is for factual updates; contradiction is for peer disagreement.

---

## Philosophy

### Staged autonomy

The LLM doesn't start with full autonomy. Early in a domain, you review every page. As patterns stabilize, autonomy widens. `explored: false → true` is the visible marker of this trust curve. Karpathy emphasized this point specifically: *"It's not a fully autonomous process. I add every source manually, one by one and I am in the loop, especially in early stages."*

### The wiki is the compiler's output

Don't edit wiki pages by hand except occasionally. If you find yourself fighting the wiki — manually rewriting the same kind of page over and over — update `AGENTS.md` to encode what you want. The schema is the control knob; the wiki is the output.

### Compounding, not accumulating

Accumulating notes is easy and worthless. Compounding is the goal: every new source *strengthens* existing pages (confirms claims, raises confidence, closes gaps), and every good query gets filed back so future queries reuse it. A page you wrote six months ago should be *more* useful today, not less.

### Prefer fewer, denser pages

A mature Concept page with 500 words synthesizing 10 sources beats 10 stub pages with 50 words each. Push toward synthesis, not catalogs.

---

## Quick reference card

| Task | Command or trigger |
|------|-------------------|
| First time in a new vault | `bin/quickstart.sh` |
| Read order each session | `hot.md` → `index.md` → specific pages |
| Ingest a source | Drop in `raw/`, say *"ingest this source"* |
| Ingest a YouTube video | `bin/yt-ingest.sh <url>`, then *"ingest the new source"* |
| Review pending pages | *"review the queue"* or `bin/review.sh` |
| Ask a research question | *"what do my sources say about X?"* |
| File an answer permanently | *"file this as an Output"* |
| Weekly maintenance | *"maintain the wiki"* or `bin/stats.sh && bin/vault-health.sh` |
| Create a new vault | `bin/<this-vault>/.agents/skills/vault-init/vault-init.sh /path/to/new` |
| Find unlinked mentions | `bin/cross-linker.sh` |
| Mandatory sections on Concepts | `## Counter-arguments`, `## Data Gaps` |
| Contradiction callout | `> [!contradiction]` (custom, styled) |
| Human-only frontmatter flip | `explored: false → true` |

For the exact schema rules and workflow steps the agent follows, read [`AGENTS.md`](AGENTS.md). For agent-facing skill definitions, read [`.agents/skills/vault-*/SKILL.md`](.agents/skills/).
