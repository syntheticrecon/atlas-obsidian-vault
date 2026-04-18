---
title: "kepano/obsidian-skills"
source: https://github.com/kepano/obsidian-skills
author: "@kepano"
type: reference
---

# Obsidian Agent Skills

> Skill specification and reference implementation for teaching agents to work with Obsidian:
> **https://github.com/kepano/obsidian-skills**

Vendored under `.agents/skills/` and made discoverable to Claude Code via symlinks in `.claude/skills/`.

## Skills this template uses

| Skill | Purpose |
|-------|---------|
| `obsidian-markdown` | Obsidian-flavored markdown: wikilinks, embeds, callouts, properties |
| `obsidian-bases` | Create/edit `.base` files (relational views over notes) |
| `obsidian-cli` | Vault operations, searches, plugin development |
| `json-canvas` | Create/edit `.canvas` files (visual knowledge graphs) |
| `defuddle` | Clean web pages to markdown before ingest |

## Agent Skills Specification

These skills follow the [Agent Skills specification](https://agentskills.io/specification) and work with any skills-compatible agent (Claude Code, Codex CLI, etc.). See the upstream repo for installation notes and version updates.
