#!/usr/bin/env bats
# End-to-end ingest simulation.
#
# Uses a fixture source + fixture expected outputs to simulate what an agent
# would produce during the Ingest workflow. Asserts the invariants that must
# hold after any ingest, regardless of LLM output quality:
#   - manifest updated with source hash + wiki_pages list
#   - all expected pages exist with valid frontmatter
#   - Sources page references Concepts/Entities bidirectionally
#   - index.md links the new pages
#   - log.md has a new ingest entry
#   - vault-health.sh reports no errors
#   - validate.py passes

VAULT_TEMPLATE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
VAULT_INIT="$VAULT_TEMPLATE/.agents/skills/vault-init/vault-init.sh"
FIXTURES="$VAULT_TEMPLATE/tests/fixtures/ingest-simulation"
TEST_VAULT="/tmp/bats-ingest-$$"

setup() {
  rm -rf "$TEST_VAULT"
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null

  # Copy input source into raw/
  cp "$FIXTURES/input/raw/"*.md "$TEST_VAULT/raw/"

  # Create expected wiki folders and copy expected pages
  mkdir -p "$TEST_VAULT/Sources" "$TEST_VAULT/Concepts" "$TEST_VAULT/Entities"
  cp "$FIXTURES/expected/Sources/"*.md "$TEST_VAULT/Sources/"
  cp "$FIXTURES/expected/Concepts/"*.md "$TEST_VAULT/Concepts/"
  cp "$FIXTURES/expected/Entities/"*.md "$TEST_VAULT/Entities/"

  # Patch manifest with the source hash and wiki_pages
  SOURCE_HASH=$(shasum -a 256 "$TEST_VAULT/raw/staged-autonomy-thread.md" | awk '{print $1}')
  cat > "$TEST_VAULT/raw/.manifest.json" <<EOF
{
  "version": 1,
  "description": "Delta tracking.",
  "sources": {
    "raw/staged-autonomy-thread.md": {
      "sha256": "$SOURCE_HASH",
      "ingested_at": "2026-04-14T12:00:00Z",
      "wiki_pages": [
        "Sources/Why Staged Autonomy Beats Full Autonomy.md",
        "Concepts/Staged Autonomy.md",
        "Concepts/Human Verification Gate.md",
        "Entities/Andrej Karpathy.md"
      ],
      "status": "current"
    }
  }
}
EOF

  # Update index.md with the new pages
  cat > "$TEST_VAULT/index.md" <<'EOF'
---
title: Index
---

# Vault Index

## Quick Links

| Page | Purpose |
|------|---------|
| [[hot]] | Session cache |
| [[log]] | Operation log |

## Sources

- [[Sources/Why Staged Autonomy Beats Full Autonomy]]

## Concepts

- [[Concepts/Staged Autonomy]]
- [[Concepts/Human Verification Gate]]

## Entities

- [[Entities/Andrej Karpathy]]

## Questions

*No open questions yet.*

## Outputs

*No outputs yet.*

## Pending

*No queued work.*
EOF

  # Append log entry
  cat >> "$TEST_VAULT/log.md" <<'EOF'

## [2026-04-14] ingest | Why Staged Autonomy Beats Full Autonomy
Processed [[Sources/Why Staged Autonomy Beats Full Autonomy]]. Created [[Concepts/Staged Autonomy]], [[Concepts/Human Verification Gate]], [[Entities/Andrej Karpathy]]. 4 new cross-links.
EOF
}

teardown() {
  rm -rf "$TEST_VAULT"
}

@test "ingest: manifest has entry for the source" {
  jq -e '.sources["raw/staged-autonomy-thread.md"]' "$TEST_VAULT/raw/.manifest.json"
}

@test "ingest: manifest sha256 matches source file" {
  stored=$(jq -r '.sources["raw/staged-autonomy-thread.md"].sha256' "$TEST_VAULT/raw/.manifest.json")
  actual=$(shasum -a 256 "$TEST_VAULT/raw/staged-autonomy-thread.md" | awk '{print $1}')
  [ "$stored" = "$actual" ]
}

@test "ingest: manifest wiki_pages lists all expected pages" {
  pages=$(jq -r '.sources["raw/staged-autonomy-thread.md"].wiki_pages | length' "$TEST_VAULT/raw/.manifest.json")
  [ "$pages" = "4" ]
}

@test "ingest: manifest status is 'current'" {
  status=$(jq -r '.sources["raw/staged-autonomy-thread.md"].status' "$TEST_VAULT/raw/.manifest.json")
  [ "$status" = "current" ]
}

@test "ingest: Sources page exists" {
  [ -f "$TEST_VAULT/Sources/Why Staged Autonomy Beats Full Autonomy.md" ]
}

@test "ingest: Concept pages exist" {
  [ -f "$TEST_VAULT/Concepts/Staged Autonomy.md" ]
  [ -f "$TEST_VAULT/Concepts/Human Verification Gate.md" ]
}

@test "ingest: Entity page exists" {
  [ -f "$TEST_VAULT/Entities/Andrej Karpathy.md" ]
}

@test "ingest: bidirectional link Sources → Concepts" {
  grep -q "\[\[Concepts/Staged Autonomy\]\]" "$TEST_VAULT/Sources/Why Staged Autonomy Beats Full Autonomy.md"
}

@test "ingest: bidirectional link Concepts → Sources" {
  grep -q "Why Staged Autonomy" "$TEST_VAULT/Concepts/Staged Autonomy.md"
}

@test "ingest: bidirectional link Sources → Entities" {
  grep -q "\[\[Entities/Andrej Karpathy\]\]" "$TEST_VAULT/Sources/Why Staged Autonomy Beats Full Autonomy.md"
}

@test "ingest: bidirectional link Entities → Sources" {
  grep -q "Why Staged Autonomy" "$TEST_VAULT/Entities/Andrej Karpathy.md"
}

@test "ingest: index.md references all new pages" {
  grep -q "Why Staged Autonomy" "$TEST_VAULT/index.md"
  grep -q "Staged Autonomy" "$TEST_VAULT/index.md"
  grep -q "Human Verification Gate" "$TEST_VAULT/index.md"
  grep -q "Andrej Karpathy" "$TEST_VAULT/index.md"
}

@test "ingest: log.md has new ingest entry" {
  grep -qE "## \[2026-04-[0-9]+\] ingest \|" "$TEST_VAULT/log.md"
}

@test "ingest: Concept pages have Counter-arguments and Data Gaps sections" {
  grep -q "## Counter-arguments" "$TEST_VAULT/Concepts/Staged Autonomy.md"
  grep -q "## Data Gaps" "$TEST_VAULT/Concepts/Staged Autonomy.md"
  grep -q "## Counter-arguments" "$TEST_VAULT/Concepts/Human Verification Gate.md"
  grep -q "## Data Gaps" "$TEST_VAULT/Concepts/Human Verification Gate.md"
}

@test "ingest: all new pages start with explored: false" {
  for page in \
    "Sources/Why Staged Autonomy Beats Full Autonomy.md" \
    "Concepts/Staged Autonomy.md" \
    "Concepts/Human Verification Gate.md" \
    "Entities/Andrej Karpathy.md"; do
    grep -q "explored: false" "$TEST_VAULT/$page"
  done
}

@test "ingest: vault-health.sh reports no ERRORS" {
  run "$TEST_VAULT/bin/vault-health.sh" "$TEST_VAULT"
  [ "$status" -eq 0 ]
  # Count lines that start with "  BROKEN" or "  MISSING status" (ERROR tier)
  errors=$(echo "$output" | grep -E "^\s*(BROKEN LINK|MISSING status)" | wc -l | tr -d ' ')
  [ "$errors" = "0" ]
}

@test "ingest: validate.py passes on simulated vault" {
  run python3 "$VAULT_TEMPLATE/tests/lint/validate.py" "$TEST_VAULT"
  [ "$status" -eq 0 ]
}

@test "ingest: validate-wikilinks.py passes on simulated vault" {
  run python3 "$VAULT_TEMPLATE/tests/lint/validate-wikilinks.py" "$TEST_VAULT"
  [ "$status" -eq 0 ]
}
