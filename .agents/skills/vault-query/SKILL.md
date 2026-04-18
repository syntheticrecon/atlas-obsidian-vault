---
name: vault-query
description: Answer a research question using the wiki. Use when the user asks a question of the form "what do my sources say about X", "where do they disagree", "summarize X and cite sources", or any question the wiki might already have synthesized. Reads hot.md, then index.md, then 5–7 relevant pages (synthesized pages before raw sources). Offers to file the answer as an Outputs/ page so future queries compound. Do NOT use for ingesting new sources (use vault-ingest) or reviewing queue (use vault-review).
---

# Vault Query Skill

Answer a research question against the existing wiki and — critically — file the answer back so future queries compound instead of re-deriving.

## When to Use

Trigger on:

- "What do my sources say about <topic>?"
- "Where do the sources disagree on <topic>?"
- "Summarize <Concept> and cite every source."
- "Is there an answer in the wiki for <question>?"
- Any research question that isn't obviously an ingest or maintenance request

## When NOT to Use

- The user is adding a new source (use `vault-ingest`)
- The user is reviewing the queue (use `vault-review`)
- The user wants a general answer not tied to the wiki (respond normally without this skill)

## Workflow

### Step 1 — Restore context

1. Read `hot.md` (session cache) first
2. Read `index.md` (navigation hub)

Token budget: ~1,500 tokens combined. If the vault is past 50 pages, `index.md` may be MOC-style with topic indexes — follow those to the right sub-index.

### Step 2 — Route to the right pages

Prefer synthesized pages (Concepts/, Entities/, Outputs/) before raw Sources/. Reading a Concept page that synthesizes 5 sources is more efficient than reading all 5 sources.

Limit: **5–7 pages per query round.** If you need more, either narrow the question with the user or file partial answers as Outputs/ pages and iterate.

Tools available for finding relevant pages:

- `rg <term>` for keyword search across the vault
- `bin/stats.sh` for a high-level view if you're not sure where to look
- Aliases in frontmatter (a page titled "Machine Learning" with `aliases: [ML]` resolves both)

### Step 3 — Synthesize the answer

When composing the response:

- **Cite every substantive claim** with a wikilink to the source: `... per [[Sources/<Title>]]`
- **Flag disagreements** explicitly with `> [!contradiction]` if sources conflict
- **Distinguish extracted vs. inferred claims** — if you're synthesizing beyond what sources state, mark with `> [!info] Inferred`
- **Note gaps** — if the wiki can't answer part of the question, say so (and suggest an ingest)
- **Respect confidence** — don't promote a `confidence: low` claim to unqualified fact

### Step 4 — Answer in chat first

Give the user the answer in the conversation. Don't file as an Output before they've seen it — they may want to refine.

### Step 5 — Offer to file the answer

If the answer is substantive and potentially reusable, ask: *"Should I file this as an Outputs/ page so future queries can reuse it?"*

If yes, create `Outputs/<Short Title>.md` using `_templates/Output.md`:

```yaml
---
query: "<the original question>"
status: current
created: <YYYY-MM-DD>
---
```

Sections:
- **Question** — the original question
- **Findings** — the synthesized answer with citations
- **Methodology** — which pages were consulted, how you decided on the answer

### Step 6 — Cross-link

Link the new Outputs/ page from the Concepts/ and Sources/ pages it draws on. Those pages now point to the filed answer — future readers find the synthesis without re-deriving.

### Step 7 — Update log and hot cache

- `log.md`: append `## [date] query | "<question>"` — note the output page created
- `hot.md`: add to Recent Changes if notable; add to Active Threads if this opened a new research direction

## Crystallization Trigger

If an Outputs/ page matures (referenced repeatedly, stabilized), consider promoting its durable insights into Concepts/ or Entities/ via the `vault-maintain` skill's crystallization workflow.

## Anti-Patterns

- **Don't skip the index.** Reading 20 sources unfiltered is a sign you didn't route through synthesized pages first.
- **Don't synthesize past the evidence.** If two sources say X and one says Y, don't present X as "most agree" — present the disagreement.
- **Don't file every chat answer.** Some questions are one-offs. File when the answer is reusable or the synthesis took work.
