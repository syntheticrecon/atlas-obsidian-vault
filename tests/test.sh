#!/bin/bash
# tests/test.sh — master test orchestrator
# Runs all available test layers and reports pass/fail.
# Usage: tests/test.sh [--fast]   # --fast skips bats integration tests

set -u

VAULT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS="$VAULT/tests"
FAST=0

for arg in "$@"; do
  case "$arg" in
    --fast) FAST=1 ;;
    -h|--help) echo "Usage: $0 [--fast]"; exit 0 ;;
  esac
done

PASSED=0
FAILED=0
SKIPPED=0
FAILS=()

run_step() {
  local name="$1"
  shift
  echo ""
  echo "================================================================"
  echo "STEP: $name"
  echo "================================================================"
  if "$@"; then
    echo "✓ PASSED: $name"
    PASSED=$((PASSED + 1))
  else
    echo "✗ FAILED: $name"
    FAILED=$((FAILED + 1))
    FAILS+=("$name")
  fi
}

skip_step() {
  local name="$1"
  local reason="$2"
  echo ""
  echo "⊘ SKIPPED: $name ($reason)"
  SKIPPED=$((SKIPPED + 1))
}

# ---------- Static / schema layer (fast, zero side effects) ----------

if command -v shellcheck >/dev/null 2>&1; then
  run_step "shellcheck-all" bash "$TESTS/lint/shellcheck-all.sh" "$VAULT"
else
  skip_step "shellcheck-all" "install with: brew install shellcheck"
fi

if command -v jq >/dev/null 2>&1; then
  run_step "validate-json" bash "$TESTS/lint/validate-json.sh" "$VAULT"
else
  skip_step "validate-json" "install with: brew install jq"
fi

if command -v python3 >/dev/null 2>&1; then
  # Check python deps
  if python3 -c "import yaml, jsonschema" 2>/dev/null; then
    run_step "validate.py (schemas + frontmatter + bases)" python3 "$TESTS/lint/validate.py" "$VAULT"
    run_step "validate-wikilinks.py" python3 "$TESTS/lint/validate-wikilinks.py" "$VAULT"
    run_step "check-schema-sync.py (AGENTS.md ↔ schema ↔ templates)" python3 "$TESTS/lint/check-schema-sync.py" "$VAULT"
    run_step "check-callouts.py (CSS snippet consistency)" python3 "$TESTS/lint/check-callouts.py" "$VAULT"
  else
    skip_step "validate.py + siblings" "pip install pyyaml jsonschema"
  fi
else
  skip_step "validate.py + siblings" "python3 not found"
fi

# ---------- Integration layer (slower, creates/removes /tmp vaults) ----------

if [ "$FAST" -eq 1 ]; then
  skip_step "bats integration tests" "--fast mode enabled"
else
  if command -v bats >/dev/null 2>&1; then
    run_step "bats: vault-init integration" bats "$TESTS/integration/vault-init.bats"
    run_step "bats: vault-init diff (template ↔ generated)" bats "$TESTS/integration/vault-init-diff.bats"
    run_step "bats: bin/ scripts" bats "$TESTS/integration/scripts.bats"
    run_step "bats: ingest simulation (end-to-end invariants)" bats "$TESTS/integration/ingest-simulation.bats"
  else
    skip_step "bats integration" "install with: brew install bats-core"
  fi
fi

# ---------- Summary ----------

echo ""
echo "================================================================"
echo "TEST SUMMARY"
echo "================================================================"
echo "Passed:  $PASSED"
echo "Failed:  $FAILED"
echo "Skipped: $SKIPPED"

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "Failed steps:"
  for f in "${FAILS[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

exit 0
