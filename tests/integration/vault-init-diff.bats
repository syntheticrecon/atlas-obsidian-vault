#!/usr/bin/env bats
# Ensure vault-init produces a new vault that matches the template.
#
# VERBATIM files: hash of generated must equal hash of template
# GENERATED files: assert required substrings are present

VAULT_TEMPLATE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
VAULT_INIT="$VAULT_TEMPLATE/.agents/skills/vault-init/vault-init.sh"
TEST_VAULT="/tmp/bats-init-diff-$$"

setup() {
  rm -rf "$TEST_VAULT"
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
}

teardown() {
  rm -rf "$TEST_VAULT"
}

hash_of() {
  # Portable sha256: macOS shasum ships with -a 256
  shasum -a 256 "$1" | awk '{print $1}'
}

# ---------- VERBATIM copies (hash must match template) ----------

@test "diff: AGENTS.md matches template" {
  [ "$(hash_of "$VAULT_TEMPLATE/AGENTS.md")" = "$(hash_of "$TEST_VAULT/AGENTS.md")" ]
}

@test "diff: TUTORIAL.md matches template" {
  [ "$(hash_of "$VAULT_TEMPLATE/TUTORIAL.md")" = "$(hash_of "$TEST_VAULT/TUTORIAL.md")" ]
}

@test "diff: all 5 templates match template verbatim" {
  for name in Source Concept Entity Question Output; do
    [ "$(hash_of "$VAULT_TEMPLATE/_templates/$name.md")" = \
      "$(hash_of "$TEST_VAULT/_templates/$name.md")" ]
  done
}

@test "diff: wiki-callouts.css matches template" {
  [ "$(hash_of "$VAULT_TEMPLATE/.obsidian/snippets/wiki-callouts.css")" = \
    "$(hash_of "$TEST_VAULT/.obsidian/snippets/wiki-callouts.css")" ]
}

@test "diff: all bin scripts match template" {
  for name in vault-health.sh cross-linker.sh yt-ingest.sh review.sh stats.sh quickstart.sh; do
    [ "$(hash_of "$VAULT_TEMPLATE/bin/$name")" = \
      "$(hash_of "$TEST_VAULT/bin/$name")" ]
  done
}

@test "diff: Vault Health.base matches template" {
  [ "$(hash_of "$VAULT_TEMPLATE/Vault Health.base")" = \
    "$(hash_of "$TEST_VAULT/Vault Health.base")" ]
}

@test "diff: raw/.manifest.json matches template" {
  [ "$(hash_of "$VAULT_TEMPLATE/raw/.manifest.json")" = \
    "$(hash_of "$TEST_VAULT/raw/.manifest.json")" ]
}

# ---------- Obsidian config files ----------

@test "diff: .obsidian/app.json matches template" {
  [ "$(hash_of "$VAULT_TEMPLATE/.obsidian/app.json")" = \
    "$(hash_of "$TEST_VAULT/.obsidian/app.json")" ]
}

@test "diff: .obsidian/appearance.json enables wiki-callouts snippet" {
  # Generated vault should copy appearance.json verbatim (snippet list included)
  jq -e '.enabledCssSnippets | index("wiki-callouts")' "$TEST_VAULT/.obsidian/appearance.json"
}

@test "diff: .obsidian/core-plugins.json matches template" {
  [ "$(hash_of "$VAULT_TEMPLATE/.obsidian/core-plugins.json")" = \
    "$(hash_of "$TEST_VAULT/.obsidian/core-plugins.json")" ]
}

# ---------- GENERATED files (structural checks) ----------

@test "diff: hot.md has all 4 required sections" {
  grep -q "^## Key Facts" "$TEST_VAULT/hot.md"
  grep -q "^## Recent Changes" "$TEST_VAULT/hot.md"
  grep -q "^## Active Threads" "$TEST_VAULT/hot.md"
  grep -q "^## Pending Review" "$TEST_VAULT/hot.md"
}

@test "diff: index.md has all 6 navigation sections" {
  grep -q "^## Quick Links" "$TEST_VAULT/index.md"
  grep -q "^## Sources" "$TEST_VAULT/index.md"
  grep -q "^## Concepts" "$TEST_VAULT/index.md"
  grep -q "^## Entities" "$TEST_VAULT/index.md"
  grep -q "^## Questions" "$TEST_VAULT/index.md"
  grep -q "^## Outputs" "$TEST_VAULT/index.md"
  grep -q "^## Pending" "$TEST_VAULT/index.md"
}

@test "diff: log.md matches template verbatim (cp -r)" {
  [ "$(hash_of "$VAULT_TEMPLATE/log.md")" = "$(hash_of "$TEST_VAULT/log.md")" ]
}

@test "diff: hot.md matches template verbatim (cp -r)" {
  [ "$(hash_of "$VAULT_TEMPLATE/hot.md")" = "$(hash_of "$TEST_VAULT/hot.md")" ]
}

@test "diff: index.md matches template verbatim (cp -r)" {
  [ "$(hash_of "$VAULT_TEMPLATE/index.md")" = "$(hash_of "$TEST_VAULT/index.md")" ]
}

# ---------- Methodology folder contents ----------

@test "diff: methodology/ contains all template methodology files" {
  for f in "$VAULT_TEMPLATE/methodology/"*.md; do
    name=$(basename "$f")
    [ -f "$TEST_VAULT/methodology/$name" ]
  done
}

@test "diff: methodology file contents match template" {
  for f in "$VAULT_TEMPLATE/methodology/"*.md; do
    name=$(basename "$f")
    [ "$(hash_of "$f")" = "$(hash_of "$TEST_VAULT/methodology/$name")" ]
  done
}

# ---------- Symlink ----------

@test "diff: CLAUDE.md is a symlink pointing to AGENTS.md" {
  [ -L "$TEST_VAULT/CLAUDE.md" ]
  [ "$(readlink "$TEST_VAULT/CLAUDE.md")" = "AGENTS.md" ]
}

# ---------- Raw/assets ----------

@test "diff: raw/assets/ exists" {
  [ -d "$TEST_VAULT/raw/assets" ]
}

# ---------- Things that SHOULD be copied (cp -r preserves everything) ----------

@test "diff: .claude/settings.json IS copied (hooks survive)" {
  [ -f "$TEST_VAULT/.claude/settings.json" ]
  [ "$(hash_of "$VAULT_TEMPLATE/.claude/settings.json")" = \
    "$(hash_of "$TEST_VAULT/.claude/settings.json")" ]
}

@test "diff: skills-lock.json IS copied (version pin survives)" {
  [ -f "$TEST_VAULT/skills-lock.json" ]
  [ "$(hash_of "$VAULT_TEMPLATE/skills-lock.json")" = \
    "$(hash_of "$TEST_VAULT/skills-lock.json")" ]
}

@test "diff: tests/ IS copied (template includes its own tests)" {
  [ -d "$TEST_VAULT/tests" ]
  [ -f "$TEST_VAULT/tests/test.sh" ]
}

# ---------- Things that should NOT be copied (cleared by vault-init) ----------

@test "diff: .claude/settings.local.json is cleared (per-session)" {
  [ ! -f "$TEST_VAULT/.claude/settings.local.json" ]
}

@test "diff: .git/ is cleared (new vault owns its history)" {
  [ ! -d "$TEST_VAULT/.git" ]
}

@test "diff: wiki content folders are NOT pre-created" {
  [ ! -d "$TEST_VAULT/Sources" ]
  [ ! -d "$TEST_VAULT/Concepts" ]
  [ ! -d "$TEST_VAULT/Entities" ]
  [ ! -d "$TEST_VAULT/Questions" ]
  [ ! -d "$TEST_VAULT/Outputs" ]
}
