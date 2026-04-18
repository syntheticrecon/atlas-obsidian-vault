---
name: vault-maintain
description: Maintain the wiki — run lint with LLM judgment, crystallize mature Outputs into Concepts/Entities, archive stale content, and promote pages through the seed → developing → mature → evergreen lifecycle. Use when the user says "lint the wiki", "health check", "clean up", "find stale pages", "promote mature concepts", or runs bin/vault-health.sh manually. Wraps the bash lint tools and adds judgment for orphan/stale/promotion decisions.
---

# Vault Maintain Skill

The weekly (or on-demand) upkeep pass. Bash tools do the mechanical checks; this skill adds the judgment — "is this really an orphan or just not yet linked?", "should this be promoted from developing to mature?", "is this Output crystallizable?"

## When to Use

- "Lint the wiki" / "run health check" / "clean up"
- "What's stale?" / "Any contradictions to resolve?"
- "Promote mature concepts"
- "Crystallize outputs into concepts"
- After a series of ingests, the user wants to consolidate

## When NOT to Use

- User is ingesting a new source (use `vault-ingest`)
- User is reviewing the queue (use `vault-review`)
- User has a specific question (use `vault-query`)

## Workflow

### Step 1 — Run the mechanical lint

```bash
bin/vault-health.sh
bin/cross-linker.sh
bin/stats.sh
```

Capture the output. The lint gives severity-tiered findings:

- **ERRORS** (must fix): broken wikilinks, missing required frontmatter
- **WARNINGS** (should address): orphans, no-outgoing-links, stale claims
- **INFO** (nice to clean up): explored:false, seed-status, missing aliases

The cross-linker suggests unlinked mentions. Stats shows the vault's shape.

### Step 2 — Fix ERRORS immediately

Broken wikilinks and missing frontmatter are never OK. Fix each one:

- Broken link → either create a stub page (if the concept is worth having) or remove the link (if it was illustrative)
- Missing `status` → add from the schema. If unclear, default to `status: seed` and mark for review

### Step 3 — Judgment pass on WARNINGS

Orphans and no-outgoing-links often look bad but may be legitimate:

- An Outputs/ page linked from nowhere is a lint failure — link it from related Concepts
- A Sources/ page linked from nowhere means nobody extracted from it — consider re-ingesting or archiving
- A Concept with no outgoing links is usually a stub — either populate it or delete (if truly unused)

Apply judgment, don't blindly fix.

### Step 4 — Spot crystallization candidates

Look for Outputs/ pages that have:

- Been referenced by 2+ other pages (via `rg -l "[[Outputs/<name>"`)
- Stabilized (no edits for a while)
- Contain reusable claims beyond the original question

For each, consider promoting durable insights into Concepts/ or Entities/:

1. Extract the reusable claims
2. Create or update the Concept/Entity page with them
3. Cross-link the Output to the new page
4. Leave the Output in place with `status: current` and the original query (it stays discoverable)

This is the compounding mechanism — Outputs become Concepts, the wiki densifies.

### Step 5 — Lifecycle promotion

For each Concept/Entity page, consider whether the status should advance:

- `seed` → `developing`: when a 2nd source confirms or extends the claim
- `developing` → `mature`: when the page has multiple sources, Counter-arguments populated, and stable structure
- `mature` → `evergreen`: human-reviewed and rarely changing

Propose promotions; let the user confirm.

### Step 6 — Archival candidates

Pages that should be marked (not deleted):

- Questions resolved by later ingests → `status: resolved`, link to the resolver
- Concepts superseded by a refined successor → `status: superseded`, link to replacement
- Outputs whose underlying claims changed → `status: superseded`

Never delete. The superseded page remains navigable for history.

### Step 7 — Update hot.md and log.md

- `log.md`: append `## [date] lint | <summary of what was fixed>`
- `hot.md`: if significant (multiple crystallizations, promotions), update Recent Changes

### Step 8 — Report

```
Lint results:
  Errors fixed:      N
  Warnings resolved: M
  Crystallized:      X Outputs → Concepts/Entities
  Promoted:          Y pages advanced lifecycle
  Archived:          Z pages marked superseded/resolved

Remaining:
  <anything deferred>

Next suggested action: <e.g., "re-ingest Sources/Foo" or "resolve [[Questions/X]] — 3 sources now support resolution">
```

## Cadence

Run weekly for an active vault. Run after every 5–10 ingests during a bulk-ingest session. Run before any major refactor.

## Anti-Patterns

- **Don't auto-archive.** Lint surfaces candidates; humans confirm.
- **Don't delete pages to fix orphans.** Links are the value; missing links are the fix, not missing pages.
- **Don't crystallize every Output.** Only those that have been used, stabilized, and contain reusable claims.
- **Don't promote on schedule.** Lifecycle advances on evidence, not time.
