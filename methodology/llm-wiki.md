---
title: LLM Wiki Pattern
source: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
author: Andrej Karpathy
type: reference
---

# The LLM Wiki Pattern

> Canonical pattern this template implements. Read the original gist for the full text:
> **https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f**

## TL;DR

A research knowledge base where an LLM agent maintains the wiki layer as markdown, and the human curates sources and asks questions. The wiki is a persistent compiled artifact that compounds over time.

## Three-layer architecture

- **Raw sources** (immutable) — articles, papers, transcripts, images
- **Wiki** (LLM-owned) — markdown files: summaries, concept pages, entity pages, index, log
- **Schema** (config file, e.g., AGENTS.md) — conventions, workflows, expectations

## Three workflows

- **Ingest** — add a source, let the LLM create/update all affected pages (~10-15 files per pass)
- **Query** — ask a question, the LLM reads the index and drills into relevant pages, answers with citations, optionally files the answer as a new page
- **Lint** — periodic health checks: orphans, duplicates, contradictions, missing concepts, data gaps

## Why it works

The bottleneck in personal knowledge bases isn't reading — it's *bookkeeping*. Updating cross-references, reconciling contradictions, re-indexing. Humans abandon wikis because maintenance grows faster than value. LLMs don't experience tedium and can touch 15 files per pass, so the maintenance cost approaches zero.

## Key design choices

- Obsidian is the viewer / IDE, the LLM is the maintainer
- The index file is load-bearing — LLM reads it first to route every query
- The log is append-only, grep-parseable, records operation history
- Outputs get filed back — queries compound the wiki rather than dying in chat
- Start simple; manual index files work surprisingly well up to ~100 sources
