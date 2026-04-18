#!/bin/bash
# quickstart.sh — Guided first-run experience for a fresh vault.
#
# Non-interactive. Prints the five things a new user needs to know, in order:
#   1. What this vault is
#   2. Where to customize it for your domain
#   3. How to ingest the first source
#   4. How to run the review loop
#   5. How to see progress
#
# Run this once right after vault-init.
#
# Usage:
#   bin/quickstart.sh [vault-path]

set -u

VAULT="${1:-.}"
cd "$VAULT" 2>/dev/null || { echo "ERROR: cannot cd to $VAULT"; exit 1; }

cat <<'EOF'
═════════════════════════════════════════════════════════════════
  Research Vault — Quickstart
═════════════════════════════════════════════════════════════════

This vault is an LLM-maintained research wiki. You curate sources
and ask questions. The LLM handles ingestion, summarization, cross-
linking, and index/log upkeep. The wiki compounds over time.

Full reference: howto.md (or AGENTS.md for the agent-facing schema).

─────────────────────────────────────────────────────────────────
STEP 1 — Customize for your domain
─────────────────────────────────────────────────────────────────

Open AGENTS.md and review:
  • "Standard Structure"       — what each folder means
  • "Recommended Frontmatter"  — fields per page type
  • "Domain Customization"     — add any domain-specific rules

The template is generic research. Your domain (ML papers? recipes?
product docs?) may need tweaks: extra page types, specific entity
categories, different confidence signals. Edit AGENTS.md to match.

─────────────────────────────────────────────────────────────────
STEP 2 — Drop your first source
─────────────────────────────────────────────────────────────────

Put any source document into raw/:
  • Web article:  use defuddle or agent-browser, save to raw/
  • YouTube:      bin/yt-ingest.sh "https://youtube.com/watch?v=..."
  • Paper PDF:    convert to markdown or plain text, save to raw/
  • Clipboard:    save manually as raw/<title>.md

Then ask the agent:
  "Ingest the new source in raw/"

The agent will follow the Ingest workflow in AGENTS.md:
  - Read the source, create Sources/<Title>.md
  - Extract Concepts, Entities, and Questions
  - Add bidirectional cross-links
  - Update index.md and log.md
  - Record the source hash in raw/.manifest.json

Every page it creates starts with `explored: false` — you review.

─────────────────────────────────────────────────────────────────
STEP 3 — Review what the agent created
─────────────────────────────────────────────────────────────────

Run the review loop:
  bin/review.sh

It walks through each explored:false page and offers:
  [a]pprove  — flip to explored: true
  [s]kip     — come back later
  [c]ontest  — add a > [!question] Contested callout
  [e]dit     — open in $EDITOR
  [q]uit     — end the session

Early in a new domain, review every page. As patterns stabilize,
the agent earns autonomy and you review fewer pages.

─────────────────────────────────────────────────────────────────
STEP 4 — Ask questions against the wiki
─────────────────────────────────────────────────────────────────

Once you have 3-5 sources ingested, start querying:
  "What do my sources say about <topic>?"
  "Where do they disagree?"
  "Summarize the <X> concept and cite every source."

If the answer is reusable, ask the agent to:
  "File this as an Outputs page"

This is the compounding mechanism — future queries read the
filed answer instead of re-deriving it.

─────────────────────────────────────────────────────────────────
STEP 5 — Watch it compound
─────────────────────────────────────────────────────────────────

Run weekly:
  bin/stats.sh         — page counts, status distribution, link density
  bin/vault-health.sh  — lint for broken links, orphans, missing frontmatter
  bin/cross-linker.sh  — scan for unlinked mentions

Signs the vault is compounding:
  - Link density rising (links per page above ~3)
  - Concepts moving from seed → developing → mature
  - Review backlog shrinking (reviewed % going up in stats)
  - Queries reusing existing Outputs instead of re-deriving

─────────────────────────────────────────────────────────────────
Quick reference
─────────────────────────────────────────────────────────────────

  bin/yt-ingest.sh <url>       Fetch YouTube transcript into raw/
  bin/review.sh                Process explored:false queue
  bin/stats.sh                 Show vault metrics
  bin/vault-health.sh          Severity-tiered lint
  bin/cross-linker.sh          Find unlinked mentions
  tests/test.sh                Full validation (if working on template)

Agent-facing docs:    AGENTS.md (symlinked as CLAUDE.md)
Human-facing docs:    howto.md
Session cache:        hot.md
Navigation hub:       index.md
Operation history:    log.md

═════════════════════════════════════════════════════════════════
EOF
