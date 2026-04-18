---
type: thread
url: "https://example.com/bookkeeping-is-the-bottleneck"
date_published: "2026-03-01"
---

# Why Bookkeeping Is the Knowledge-Base Bottleneck

Posted by an anonymous researcher, March 2026. Use this as a first-ingest
fixture — drop it into `raw/` and ask the agent to ingest.

## The claim

Most people who start a research wiki abandon it within six months. Not
because the information isn't useful — because the *maintenance* grows
faster than the *value*. Every new source means updating cross-references,
rewriting summaries, pruning contradictions, re-indexing. That work is
tedious, repetitive, and easy to defer. Once you defer, the wiki stales;
once it stales, you stop trusting it; once you stop trusting it, you
abandon it.

## The inversion

LLMs don't experience tedium. They can open fifteen files in a single
pass, edit each one, and never forget to update the index. The work that
breaks humans is the work they're best at.

So the pattern is: humans curate sources and ask good questions. LLMs
handle the mechanical synthesis, linking, and upkeep. The human stays
in the loop early to teach the ontology; as the LLM internalizes the
pattern, it earns more autonomy.

## What makes it compound

Three features turn this into a compounding system:

1. **Persistent artifact.** The wiki is markdown in a directory, version-
   controlled, readable by anything. It doesn't live in chat history.
2. **File-it-back.** Query answers get filed as pages. Future queries
   read the filed answer instead of re-deriving it.
3. **Cross-linking.** Every new source strengthens existing pages by
   adding links, updating claims, raising confidence.

## Caveats

The LLM can hallucinate, drift ontology over time, and create duplicate
pages if the schema isn't maintained. Lint passes and human review are
necessary safeguards. The schema document — one file defining conventions —
is load-bearing: it's where the human encodes their preferences so the LLM
stays consistent.
