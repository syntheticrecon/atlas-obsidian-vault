#!/usr/bin/env bats
# Unit-style tests for bin/ scripts using fixtures.

VAULT_TEMPLATE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
VAULT_INIT="$VAULT_TEMPLATE/.agents/skills/vault-init/vault-init.sh"
FIXTURES="$VAULT_TEMPLATE/tests/fixtures"
TEST_VAULT="/tmp/bats-scripts-$$"

setup() {
  rm -rf "$TEST_VAULT"
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
}

teardown() {
  rm -rf "$TEST_VAULT"
}

# ---------- vault-health.sh ----------

@test "vault-health detects broken wikilink" {
  mkdir -p "$TEST_VAULT/Sources"
  cat > "$TEST_VAULT/Sources/Test.md" <<'EOF'
---
type: article
explored: false
---
# Test
Links to [[NonexistentPage]].
EOF
  run "$TEST_VAULT/bin/vault-health.sh" "$TEST_VAULT"
  [[ "$output" == *"BROKEN LINK"* ]]
  [[ "$output" == *"NonexistentPage"* ]]
}

@test "vault-health detects missing status frontmatter" {
  mkdir -p "$TEST_VAULT/Concepts"
  cat > "$TEST_VAULT/Concepts/NoStatus.md" <<'EOF'
---
confidence: medium
explored: false
---
# No Status
EOF
  run "$TEST_VAULT/bin/vault-health.sh" "$TEST_VAULT"
  [[ "$output" == *"MISSING status"* ]] || [[ "$output" == *"NoStatus"* ]]
}

@test "vault-health detects explored:false pages in INFO tier" {
  mkdir -p "$TEST_VAULT/Concepts"
  cp "$FIXTURES/valid/Concept-valid.md" "$TEST_VAULT/Concepts/"
  run "$TEST_VAULT/bin/vault-health.sh" "$TEST_VAULT"
  [[ "$output" == *"NEEDS REVIEW"* ]] || [[ "$output" == *"explored"* ]] || [[ "$output" == *"INFO"* ]]
}

# ---------- cross-linker.sh ----------

@test "cross-linker finds unlinked mentions" {
  mkdir -p "$TEST_VAULT/Concepts"
  cat > "$TEST_VAULT/Concepts/Widget.md" <<'EOF'
---
status: developing
confidence: medium
explored: false
---
# Widget
EOF
  cat > "$TEST_VAULT/Concepts/Gadget.md" <<'EOF'
---
status: developing
confidence: medium
explored: false
---
# Gadget
Mentions Widget without linking it.
EOF
  run "$TEST_VAULT/bin/cross-linker.sh" "$TEST_VAULT"
  [[ "$output" == *"UNLINKED"* ]] || [[ "$output" == *"Widget"* ]]
}

@test "cross-linker skips names shorter than 4 chars" {
  mkdir -p "$TEST_VAULT/Concepts"
  cat > "$TEST_VAULT/Concepts/AI.md" <<'EOF'
---
status: seed
confidence: low
explored: false
---
# AI
EOF
  cat > "$TEST_VAULT/Concepts/Other.md" <<'EOF'
---
status: seed
confidence: low
explored: false
---
# Other
AI is mentioned many times but too short.
EOF
  run "$TEST_VAULT/bin/cross-linker.sh" "$TEST_VAULT"
  # Should NOT flag "AI" because it's < 4 chars
  [[ "$output" != *"UNLINKED: 'AI'"* ]]
}

# ---------- yt-ingest.sh ----------

@test "yt-ingest exits with usage when missing URL" {
  run "$TEST_VAULT/bin/yt-ingest.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "yt-ingest rejects unknown flags" {
  run "$TEST_VAULT/bin/yt-ingest.sh" "https://example.com" --bogus-flag
  [ "$status" -ne 0 ]
}

@test "yt-ingest does NOT use bash 4+ mapfile syntax" {
  ! grep -E "^\\s*(mapfile|readarray)" "$TEST_VAULT/bin/yt-ingest.sh"
}

# ---------- review.sh ----------

@test "review reports empty queue on fresh vault" {
  run "$TEST_VAULT/bin/review.sh" --count "$TEST_VAULT"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "review --list reports empty message on fresh vault" {
  run "$TEST_VAULT/bin/review.sh" --list "$TEST_VAULT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"empty"* ]]
}

@test "review --count finds explored:false pages" {
  mkdir -p "$TEST_VAULT/Concepts"
  cat > "$TEST_VAULT/Concepts/Pending.md" <<'EOF'
---
status: seed
confidence: low
explored: false
---
# Pending
EOF
  run "$TEST_VAULT/bin/review.sh" --count "$TEST_VAULT"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# ---------- stats.sh ----------

@test "stats.sh runs on fresh vault without error" {
  run "$TEST_VAULT/bin/stats.sh" "$TEST_VAULT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Vault Stats"* ]]
  [[ "$output" == *"Page counts"* ]]
}

@test "stats.sh counts pages correctly" {
  mkdir -p "$TEST_VAULT/Concepts" "$TEST_VAULT/Entities"
  echo "---
status: seed
confidence: low
explored: false
---
# A" > "$TEST_VAULT/Concepts/A.md"
  echo "---
status: mature
confidence: high
explored: true
---
# B" > "$TEST_VAULT/Entities/B.md"
  run "$TEST_VAULT/bin/stats.sh" "$TEST_VAULT"
  [[ "$output" == *"Concepts/     1"* ]] || [[ "$output" == *"Concepts/    1"* ]]
  [[ "$output" == *"Entities/     1"* ]] || [[ "$output" == *"Entities/    1"* ]]
}

# ---------- quickstart.sh ----------

@test "quickstart.sh runs on fresh vault and prints all 5 steps" {
  run "$TEST_VAULT/bin/quickstart.sh" "$TEST_VAULT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STEP 1"* ]]
  [[ "$output" == *"STEP 2"* ]]
  [[ "$output" == *"STEP 3"* ]]
  [[ "$output" == *"STEP 4"* ]]
  [[ "$output" == *"STEP 5"* ]]
}
