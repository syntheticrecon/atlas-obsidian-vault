---
title: Vault Template Improvement Proposal
created: 2026-04-12
type: output
status: draft
---

# Vault Template Improvement Proposal

This proposal synthesizes findings from a team exploration of the vault template, its methodology documents, CLAUDE.md configuration, and skills setup. It identifies what works well, what's missing, and proposes prioritized improvements.

## Current State

The vault is a **clean, pre-ingest template** — no sources have been ingested yet. The foundation is solid:

- CLAUDE.md (AGENTS.md) provides clear workflows for ingest, query, and lint
- Six skills are vendored and version-locked (agent-browser, obsidian-markdown, obsidian-bases, json-canvas, obsidian-cli, defuddle)
- Methodology docs articulate the core LLM-wiki pattern well
- index.md and log.md scaffolds are in place
- Standard folders are defined but created on demand

## What Works Well

- **The compiler metaphor is strong.** Sources are input, the wiki is compiled output, the LLM is the compiler. This mental model is clear and actionable.
- **One-at-a-time ingest with staged autonomy.** Human oversight early, earned LLM autonomy later. This prevents premature ontology decisions.
- **Three workflows (ingest/query/lint) are well-structured.** Steps are concrete and sequenced correctly.
- **Skills coverage is comprehensive.** Web ingest (agent-browser + defuddle), note editing (obsidian-markdown), structured data (bases), visualization (canvas), and vault ops (cli) cover the core needs.
- **"File it back" philosophy.** Query outputs compound back into the wiki rather than dying in chat. This is the key differentiator from naive RAG.
- **Structure aligns with community consensus.** Templates like [second-brain](https://github.com/NicholasSpisak/second-brain), [obsidian-wiki](https://github.com/Ar9av/obsidian-wiki), and [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian) all follow similar source/concept/entity separation.

## Proposed Improvements

### Priority 1: Strengthen CLAUDE.md Guidance

These address the most likely sources of LLM confusion during actual use.

#### 1.1 Add Cross-Linking Rules

The current guide says "add cross-links" but doesn't specify when or how. Add a section:

> [!example] Suggested addition to CLAUDE.md
> **Cross-Linking Guidelines:**
> - Link bidirectionally between Sources/ and the Concepts/Entities they inform
> - Link Questions/ pages to the Concepts/ or Sources/ pages that raised them
> - Prefer inline wikilinks in context over link dump sections at the bottom
> - Don't over-link: if a concept is mentioned 5 times on a page, link it on first mention only
> - Obsidian handles cross-folder links transparently — `[[Page Name]]` works from anywhere
> - Add `aliases` to frontmatter for synonyms (e.g., `aliases: [ML, statistical learning]`) — this prevents duplicate concepts and enables synonym-based discovery

#### 1.2 Define Claim Provenance and Uncertainty Syntax

The guide says "label uncertain claims clearly" but gives no format. The [LLM Wiki v2 pattern](https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2) and community implementations converge on:

> [!example] Suggested conventions
> **Provenance tagging** — mark non-obvious claims as one of:
> - *extracted* (default) — directly stated in the source
> - *inferred* — LLM synthesis: `> [!info] Inferred — [claim and reasoning]`
> - *ambiguous* — sources disagree: `> [!question] Contested — Source A says X, Source B says Y`
> - *uncertain* — plausible but unconfirmed: `> [!warning] Uncertain — [claim and why]`
>
> **Confidence metadata** — add `confidence: high | medium | low` to frontmatter on Concepts/ and Entities/ pages. Queryable via Bases for lint dashboards.

#### 1.3 Add Source Conflict Workflow

When two sources contradict each other, the agent currently has no guidance. The LLM Wiki v2 pattern distinguishes **supersession** (temporal evolution) from **contradiction** (genuine disagreement):

> [!example] Suggested addition
> **When sources conflict:**
> 1. Determine: is this supersession (newer data replaces older) or contradiction (contemporaneous disagreement)?
> 2. For supersession: update the claim, mark the old version with `> [!info] Superseded by [[Newer Source]]`
> 3. For contradiction: note the conflict on both Sources/ pages and create or update a Questions/ page
> 4. On Concepts/ pages, present both positions with source attribution using `> [!question] Contested` callouts
> 5. Do not silently choose one source over another

#### 1.4 Clarify Entity vs. Concept Boundary

Add a decision heuristic:

> [!example] Suggested heuristic
> - **Entity**: a proper noun — a specific person, organization, product, place, or text. Has a fixed identity. (e.g., "Andrej Karpathy", "Obsidian", "Vannevar Bush")
> - **Concept**: an idea, pattern, or category that spans sources. Not a proper noun. (e.g., "Knowledge Compilation", "Staged Autonomy", "Claim Extraction")
> - When in doubt, prefer Concept. Entities are for things you'd find in a directory; Concepts are for things you'd find in a glossary.

#### 1.5 Specify log.md Format

The log is "append-only" but format-free. Standardize:

> [!example] Suggested format
> ```
> ## [2026-04-12] ingest | Source Title
> Processed [[Source Page]]. Created [[New Concept]], updated [[Existing Entity]]. 3 new cross-links.
>
> ## [2026-04-12] query | "What is the relationship between X and Y?"
> Created [[Outputs/X-Y Relationship]]. Updated [[Concept Page]] with new synthesis.
>
> ## [2026-04-12] lint
> Found 2 orphaned pages, 1 stale claim. Fixed.
> ```

### Priority 2: Add Missing Workflows

These cover scenarios the current template doesn't address but will encounter in practice.

#### 2.1 Bulk Ingest Workflow

When a user drops multiple sources at once:

1. List all new sources and ask the user for priority order (or use chronological)
2. Ingest one at a time, updating wiki between each
3. After every 5 sources, do a mini-lint pass to catch emerging duplicates or ontology drift
4. Report a summary at the end

#### 2.2 Source Update Workflow

When a newer version of an existing source arrives:

1. Add the new version to raw/ (don't replace the old one)
2. Update the Sources/ page with a "Version History" section
3. Walk affected Concepts/ and Entities/ pages to update or flag stale claims
4. Log the update with a clear notation that it's a revision, not a new source

#### 2.3 Archival / Deprecation Workflow

Define when and how to retire content:

- Questions/ pages can be closed when resolved — move to a `## Resolved` section or add `status: resolved` to frontmatter
- Outputs/ pages that are superseded by newer analysis should be marked `status: superseded` with a link to the replacement
- Don't delete pages; mark them and let lint passes identify candidates for cleanup

#### 2.4 Page Lifecycle

Every wiki page moves through stages:

```
created → draft → active → stale → superseded/archived
```

Track this with a `status` frontmatter field. Lint passes should flag pages that haven't been updated after N new related sources.

#### 2.5 Crystallization Workflow

When query outputs in Outputs/ prove valuable over time, promote key findings back into Concepts/ or Entities/ pages. Treat completed explorations as knowledge sources themselves — the wiki compounds on its own output.

### Priority 3: Operational Improvements

#### 3.1 Recommended Frontmatter Schema

Define optional-but-useful properties per page type:

| Page Type | Recommended Properties |
|-----------|----------------------|
| Sources/ | `source_file`, `url`, `date_published`, `date_ingested`, `type` (article/paper/thread/book) |
| Concepts/ | `status`, `confidence`, `source_count`, `needs_review`, `aliases` |
| Entities/ | `type` (person/org/product/tool/text), `status`, `aliases` |
| Questions/ | `status` (open/investigating/resolved), `raised_by` (source that prompted it) |
| Outputs/ | `query`, `status` (current/superseded), `created` |

#### 3.2 Lint Checklist with Commands

Make the lint workflow actionable with concrete commands:

- **Orphaned pages**: `rg -l "." Sources/ Concepts/ Entities/ | while read f; do rg -l "$(basename "$f" .md)" --glob '!'"$f" . || echo "ORPHAN: $f"; done`
- **Pages with no outgoing links**: `rg -L "\[\[" Sources/ Concepts/ Entities/`
- **Stale index entries**: Compare index.md links against actual files
- **Empty sections**: `rg -l "^## " --glob "*.md" | xargs rg -c "\S"` to find skeleton pages

#### 3.3 Index Structure for Growth

As the vault grows, index.md should evolve. Suggest phases:

- **0-20 pages**: Flat list under each section header (current format)
- **20-50 pages**: Add one-line descriptions next to each link
- **50-100 pages**: Group by subtopic within each section
- **100+ pages**: Consider a Maps of Content (MOC) pattern — one index per major topic area, with index.md linking to MOCs

### Priority 4: Tooling & Automation

#### 4.1 Create a Vault Health Dashboard

Use Obsidian Bases to create a `.base` file showing pages by type, confidence level, link count, and orphan status. Makes lint operations visible without running commands. Bases is already enabled in this vault.

#### 4.2 Consider qmd for Scale

The methodology mentions `qmd` as a local search engine for markdown (BM25 + vector search). At 50+ sources, consider installing it to supplement index-based navigation.

#### 4.3 Canvas for Domain Mapping

Create a `.canvas` file as a visual MOC for the research domain, showing how major concepts relate spatially. Useful for onboarding new sessions and spotting structural gaps.

#### 4.4 Obsidian LLM Wiki Plugin

A community plugin ([forum thread](https://forum.obsidian.md/t/new-plugin-llm-wiki-turn-your-vault-into-a-queryable-knowledge-base-privately/113223)) runs locally via Ollama with hybrid search and auto entity extraction. Worth evaluating if the vault grows beyond index-based navigation.

## Known Pitfalls to Watch For

From community experience and research:

- **Hallucination in synthesis**: Top LLMs cluster at 10-20% hallucination rates. Every claim must trace to a source page, and source pages to raw/. Regular lint catches drift.
- **Ontology drift**: Without schema governance, the LLM creates synonymous concepts ("Machine Learning" vs "ML" vs "Statistical Learning"). Mitigation: aliases in frontmatter, controlled vocabulary in CLAUDE.md.
- **Duplicate pages**: Multiple ingest sessions create overlapping pages. Mitigation: "update before create" rule (already in CLAUDE.md), lint for overlapping scope.
- **Link rot**: External URLs decay. Mitigation: download assets locally to raw/assets/.
- **Loss of understanding**: Outsourcing bookkeeping risks building reference without learning. Mitigation: human stays in the loop during ingest, reviews critically.

## What to Defer

- **Multi-agent coordination patterns** — not needed until vault is actively populated
- **Synthetic data / finetuning** — mentioned in Karpathy thread as future direction, premature now
- **RAG infrastructure** — index.md approach is sufficient well past 100 sources
- **Git version control** — useful but not required for the template itself; the user can initialize when ready

## Summary

The template is well-designed and ready for use. The improvements above fall into four tiers:

1. **Strengthen CLAUDE.md** — cross-linking rules, provenance syntax, conflict workflow, entity/concept boundary, log format, aliases
2. **Add missing workflows** — bulk ingest, source updates, archival, page lifecycle, crystallization
3. **Operational improvements** — frontmatter schema, lint checklist, index scaling strategy
4. **Tooling** — Bases health dashboard, qmd search, canvas MOCs

The highest-impact changes are in Priority 1 — they directly reduce LLM confusion during the most common operation (ingest) and cost nothing to implement.

## Sources & References

- [Karpathy LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- [LLM Wiki v2 pattern](https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2)
- [second-brain implementation](https://github.com/NicholasSpisak/second-brain)
- [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian)
- [Obsidian LLM Wiki plugin](https://forum.obsidian.md/t/new-plugin-llm-wiki-turn-your-vault-into-a-queryable-knowledge-base-privately/113223)

## Related

- [[methodology/llm-wiki|LLM Wiki Pattern]]
- [[index|Vault Index]]
- [[log|Activity Log]]
