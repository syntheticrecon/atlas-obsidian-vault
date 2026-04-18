---
name: vault-init
description: Initialize a new research vault with the standard directory structure, Obsidian configuration, AGENTS.md, templates, custom callouts, hot cache, delta tracking manifest, and utility scripts. Use when the user asks to create a new vault, initialize a vault, or set up a new research knowledge base.
---

# Vault Init Skill

Initialize a new research vault with the standard directory structure, Obsidian configuration, and agent instructions following the LLM-wiki pattern.

## Usage

```bash
".agents/skills/vault-init/vault-init.sh" "<path-to-new-vault>"
```

Example:
```bash
".agents/skills/vault-init/vault-init.sh" "/path/to/my-new-research-vault"
```

## Vault Structure Created

```
vault-name/
├── .obsidian/                          # Obsidian configuration
│   ├── app.json
│   ├── appearance.json                 # Enables wiki-callouts CSS snippet
│   ├── core-plugins.json
│   ├── graph.json
│   ├── workspace.json
│   └── snippets/
│       └── wiki-callouts.css           # Custom callouts: contradiction, gap, key-insight, stale
├── _templates/                         # Page templates per type
│   ├── Source.md
│   ├── Concept.md                      # Includes Counter-arguments & Data Gaps
│   ├── Entity.md
│   ├── Question.md
│   └── Output.md
├── bin/                                # Utility scripts (executable)
│   ├── vault-health.sh                 # Severity-tiered lint
│   ├── cross-linker.sh                 # Finds unlinked mentions
│   └── yt-ingest.sh                    # yt-dlp wrapper for video ingest
├── methodology/                        # Canonical reference documents
│   ├── llm-wiki.md
│   └── 2026-04-02T204221.000Z - Thread by @karpathy.md
├── raw/                                # Immutable source documents
│   ├── assets/                         # Local images/attachments
│   └── .manifest.json                  # Delta tracking (source hashes → wiki pages)
├── AGENTS.md                           # Agent schema (canonical)
├── CLAUDE.md                           # Symlink → AGENTS.md
├── Vault Health.base                   # Obsidian Bases dashboard
├── hot.md                              # Session continuity cache
├── index.md                            # Navigation hub
└── log.md                              # Append-only operation record
```

**Note:** Wiki content folders (`Sources/`, `Concepts/`, `Entities/`, `Questions/`, `Outputs/`) are **created on demand** during first ingest — not pre-created. This matches the AGENTS.md principle of minimal scaffolding.

## What's Included

- **Agent schema** (`AGENTS.md`): Full instructions for ingest, query, lint workflows plus conventions for cross-linking, provenance, source conflicts, page lifecycle, frontmatter schema, and more
- **Custom callouts CSS**: Styled callouts for contradictions, gaps, key insights, and stale claims
- **Page templates**: Starter scaffolds with correct frontmatter for each page type
- **Hot cache** (`hot.md`): Session continuity file for cross-session context
- **Delta tracking** (`raw/.manifest.json`): Hash-based source tracking to prevent re-ingesting
- **Vault Health dashboard** (`Vault Health.base`): Obsidian Bases view with multiple lenses
- **Utility scripts**: `vault-health.sh` (severity-tiered lint), `cross-linker.sh` (unlinked mentions), `yt-ingest.sh` (video transcripts)
- **Methodology docs**: The LLM-wiki pattern reference and Karpathy thread
- **Obsidian config**: Bases, Canvas, Properties, Backlinks, Graph pre-enabled

## What's NOT Copied

- `skills-lock.json` — each vault manages its own skills
- `.agents/` contents — skills vendored per vault
- `.claude/settings.json` — each project manages its own Claude Code config
- Any raw source files or existing wiki pages — start fresh

## After Initialization

1. Open the vault in Obsidian
2. Read `AGENTS.md` (or `CLAUDE.md`) to understand conventions
3. Drop the first source into `raw/` and begin ingesting (follow the Ingest workflow in AGENTS.md)
4. The hot cache, index, and log will populate as you work
