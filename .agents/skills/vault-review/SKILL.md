---
name: vault-review
description: Walk the human-review queue — pages in Sources/, Concepts/, Entities/ with `explored: false`. Use when the user says "review the queue", "work through pending pages", "check what the agent created", or asks for a review session. Applies LLM judgment per page — not just a bash menu — to approve, flag contested claims, propose edits, or spot duplicates. Do NOT use for ingest (use vault-ingest) or querying (use vault-query).
---

# Vault Review Skill

Walk the human-review queue with actual judgment. Every AI-created page starts with `explored: false`; a human flips it to `true` after reviewing. This skill helps the human reviewer by doing the heavy reading and pointing out what to notice.

## When to Use

Trigger on any of:

- "Review the queue"
- "Walk through the pending pages"
- "What needs review?"
- "Check what you created"
- After a `vault-ingest` session the user wants to validate

## When NOT to Use

- The user wants to read a specific page — just read it
- The user wants bulk approve without reading — that defeats the point; refuse and explain
- The queue is empty — report `bin/review.sh --count` and stop

## Workflow

### Step 1 — List the queue

```
bin/review.sh --list
```

This returns all files in `Sources/`, `Concepts/`, `Entities/` with `explored: false`. If empty, report and stop.

### Step 2 — Walk each page with judgment

For each page in the queue, don't just display it — *read* it and report:

1. **Show the page** (frontmatter + first 40–50 lines of body)
2. **Spot-check**:
   - Are Concepts/Entities properly cross-linked back to the Sources/ page?
   - For Concepts/: are Counter-arguments and Data Gaps sections present and non-trivial?
   - Does `confidence` match the evidence (multiple sources = high, single source = low)?
   - Is this a duplicate of an existing page (check aliases, similar-titled pages)?
   - Any claims that look inferred but aren't marked `> [!info] Inferred`?
   - Any `status: high confidence` paired with thin evidence?
3. **Propose an action**: approve / approve-with-edits / contest / mark-duplicate / skip
4. **Wait for user** to confirm or adjust

### Step 3 — Apply the action

**Approve** (frontmatter flips): use Edit to change `explored: false` → `explored: true`. Optional: bump `status` (seed → developing if 2+ sources) or `confidence` (medium → high if well-supported).

**Contest** (keep explored: false, add a note): append:

```
> [!question] Contested (review YYYY-MM-DD)
> <reviewer's note>
```

Cross-link to a new or existing Questions/ page if the contest is substantive.

**Mark duplicate**: if the page is a duplicate of an existing one:
- Merge useful content into the canonical page
- Add the duplicate's title to the canonical page's `aliases:`
- Update all inbound links to point to the canonical page
- Delete the duplicate (this is the one case where deletion is OK — duplicates have no history worth preserving)
- Report clearly what was merged

**Skip**: leave as-is; note that it stayed in the queue.

### Step 4 — Update hot.md

After the session, update hot.md's "Pending Review" section to reflect the new count. If the user approved or contested a notable page, note it in "Recent Changes."

### Step 5 — Report session summary

```
Reviewed: N pages
  Approved: X
  Contested: Y
  Duplicates merged: Z
  Skipped (remaining): W

Queue size: before → after
```

## Non-Interactive Shortcuts

- `bin/review.sh --count` — queue size only
- `bin/review.sh --list` — list of files
- `bin/review.sh` — bash-driven interactive mode (menu-based, no LLM judgment)

Prefer the LLM-driven workflow for substantive review. The bash script is for when the user wants fast menu-driven approvals.

## Anti-Patterns

- **Don't bulk-approve.** If the user says "just approve everything," refuse — the point of review is judgment.
- **Don't flip `explored` to `true` without reading.** Frontmatter drift is a silent failure mode.
- **Don't create new pages during review.** This is a verification loop, not an authoring loop. If review reveals a missing Concept, flag it for the next ingest or query — don't sneak it in.
