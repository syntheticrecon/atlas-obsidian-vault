#!/usr/bin/env bats
# End-to-end vault-init flow: scaffold, verify structure, run scripts, cleanup.

VAULT_TEMPLATE="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
VAULT_INIT="$VAULT_TEMPLATE/.agents/skills/vault-init/vault-init.sh"
TEST_VAULT="/tmp/bats-vault-$$"

setup() {
  rm -rf "$TEST_VAULT"
}

teardown() {
  rm -rf "$TEST_VAULT"
}

@test "vault-init.sh exists and is executable" {
  [ -x "$VAULT_INIT" ]
}

@test "vault-init refuses to overwrite existing path" {
  mkdir -p "$TEST_VAULT"
  run "$VAULT_INIT" "$TEST_VAULT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "vault-init creates a new vault successfully" {
  run "$VAULT_INIT" "$TEST_VAULT"
  [ "$status" -eq 0 ]
  [ -d "$TEST_VAULT" ]
}

@test "new vault does NOT pre-create wiki folders" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ ! -d "$TEST_VAULT/Sources" ]
  [ ! -d "$TEST_VAULT/Concepts" ]
  [ ! -d "$TEST_VAULT/Entities" ]
  [ ! -d "$TEST_VAULT/Questions" ]
  [ ! -d "$TEST_VAULT/Outputs" ]
}

@test "new vault uses methodology/ not reference/" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ -d "$TEST_VAULT/methodology" ]
  [ ! -d "$TEST_VAULT/reference" ]
}

@test "new vault has all required root files" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ -f "$TEST_VAULT/AGENTS.md" ]
  [ -f "$TEST_VAULT/hot.md" ]
  [ -f "$TEST_VAULT/howto.md" ]
  [ -f "$TEST_VAULT/index.md" ]
  [ -f "$TEST_VAULT/log.md" ]
  [ -f "$TEST_VAULT/Vault Health.base" ]
  [ -L "$TEST_VAULT/CLAUDE.md" ]
}

@test "new vault CLAUDE.md symlink resolves to AGENTS.md" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  target=$(readlink "$TEST_VAULT/CLAUDE.md")
  [ "$target" = "AGENTS.md" ]
  # And the file it points to exists
  [ -f "$TEST_VAULT/CLAUDE.md" ]
}

@test "new vault has all 5 templates" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ -f "$TEST_VAULT/_templates/Source.md" ]
  [ -f "$TEST_VAULT/_templates/Concept.md" ]
  [ -f "$TEST_VAULT/_templates/Entity.md" ]
  [ -f "$TEST_VAULT/_templates/Question.md" ]
  [ -f "$TEST_VAULT/_templates/Output.md" ]
}

@test "vault-init duplicates skills from template (via cp -r)" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ -d "$TEST_VAULT/.agents/skills" ]
  # Vault-native skills present
  for skill in vault-ingest vault-query vault-review vault-maintain vault-init; do
    [ -f "$TEST_VAULT/.agents/skills/$skill/SKILL.md" ]
  done
  # Claude Code symlinks present
  [ -L "$TEST_VAULT/.claude/skills/vault-ingest" ]
}

@test "vault-init clears user-generated wiki folders" {
  # Create content in the source shouldn't happen in reality, but verify the
  # script clears wiki folders regardless.
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ ! -d "$TEST_VAULT/Sources" ]
  [ ! -d "$TEST_VAULT/Concepts" ]
  [ ! -d "$TEST_VAULT/Entities" ]
  [ ! -d "$TEST_VAULT/Questions" ]
  [ ! -d "$TEST_VAULT/Outputs" ]
}

@test "vault-init clears per-session settings.local.json" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ ! -f "$TEST_VAULT/.claude/settings.local.json" ]
}

@test "vault-init clears .git (if template was a git repo)" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ ! -d "$TEST_VAULT/.git" ]
}

@test "vault-init produces a fresh empty manifest" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  empty=$(jq '.sources | length' "$TEST_VAULT/raw/.manifest.json")
  [ "$empty" = "0" ]
}

@test "new vault bin/ scripts are executable" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  for name in vault-health.sh cross-linker.sh yt-ingest.sh review.sh stats.sh quickstart.sh; do
    [ -x "$TEST_VAULT/bin/$name" ]
  done
}

@test "new vault has CSS snippet installed and enabled" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ -f "$TEST_VAULT/.obsidian/snippets/wiki-callouts.css" ]
  grep -q "wiki-callouts" "$TEST_VAULT/.obsidian/appearance.json"
}

@test "new vault has valid manifest.json" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ -f "$TEST_VAULT/raw/.manifest.json" ]
  jq empty "$TEST_VAULT/raw/.manifest.json"
}

@test "new vault has raw/assets directory" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  [ -d "$TEST_VAULT/raw/assets" ]
}

@test "vault-health.sh runs cleanly on new empty vault" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  run "$TEST_VAULT/bin/vault-health.sh" "$TEST_VAULT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Vault Health Check"* ]]
}

@test "cross-linker.sh runs cleanly on new empty vault" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  run "$TEST_VAULT/bin/cross-linker.sh" "$TEST_VAULT"
  [ "$status" -eq 0 ]
}

@test "yt-ingest.sh shows usage when called with no args" {
  "$VAULT_INIT" "$TEST_VAULT" >/dev/null
  run "$TEST_VAULT/bin/yt-ingest.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}
