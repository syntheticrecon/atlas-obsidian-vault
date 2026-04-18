---
source_file: "raw/staged-autonomy-thread.md"
url: "https://example.com/thread"
date_published: "2026-03-15"
type: thread
---

# Why Staged Autonomy Beats Full Autonomy

Posted by Andrej Karpathy, March 2026.

The tedious part of maintaining a knowledge base is not the reading or the
thinking — it's the bookkeeping. Humans abandon wikis because maintenance
cost grows faster than value. LLMs don't get bored.

But one-shot autonomy is a trap. Early in a domain, the LLM hasn't seen
your patterns yet. If you let it run unsupervised on the first 20 sources,
you'll end up with a messy ontology.

Staged autonomy: human in the loop for the first N sources to establish
the schema. Then the LLM earns autonomy by demonstrating it's internalized
your patterns. The `explored: false` flag in Obsidian is the visible marker
of that trust curve.
