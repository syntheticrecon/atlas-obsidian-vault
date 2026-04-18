---
title: "Karpathy on LLM Knowledge Bases"
source: https://x.com/karpathy/status/2039805659525644595
author: Andrej Karpathy
date_published: 2026-04-02
type: reference
---

# Karpathy on LLM Knowledge Bases

> Practical workflow notes from the original X thread:
> **https://x.com/karpathy/status/2039805659525644595**

## Key points

### Staged autonomy is essential

> "It's not a fully autonomous process. I add every source manually, one by one and I am in the loop, especially in early stages. After a while, the LLM 'gets' the pattern and the marginal document is a lot easier."

Early ingest requires human oversight to establish patterns. Only after ~N sources (often 20-50) does the LLM earn autonomy. This directly contradicts naive batch-processing and is the strongest argument for the `explored: false` verification gate.

### Workflow summary

1. Index sources into `raw/` (Obsidian Web Clipper, local image download)
2. LLM incrementally compiles a wiki with summaries, backlinks, cross-linking
3. Obsidian serves as the IDE (view raw data, compiled wiki, visualizations)
4. Query the wiki with complex questions; LLM synthesizes with citations
5. File outputs back into the wiki to compound knowledge
6. Run periodic health checks — find inconsistent data, propose new article candidates

### Scale observations

At ~100 articles and ~400K words, manual index files with brief summaries are sufficient. RAG infrastructure isn't needed yet.

### Future directions

Synthetic data generation + finetuning to embed wiki knowledge directly in model weights — moving from context window to parameter-level knowledge. Not implemented in this template.
