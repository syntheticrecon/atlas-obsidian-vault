#!/bin/bash
# Run shellcheck on every bash script in the vault.
# (Script name: shellcheck-all.sh — this comment is reformatted so that
# the word "shellcheck" is not the first token on a comment line,
# which shellcheck otherwise misinterprets as a directive.)
# Exits non-zero if any script has shellcheck errors.

set -u

VAULT="${1:-.}"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "ERROR: shellcheck not installed. Install with: brew install shellcheck"
  exit 2
fi

FAILED=0
while IFS= read -r -d '' script; do
  # Skip vendored skills (not our code)
  case "$script" in
    */.agents/skills/agent-browser/*) continue ;;
    */.agents/skills/defuddle/*) continue ;;
    */.agents/skills/json-canvas/*) continue ;;
    */.agents/skills/obsidian-bases/*) continue ;;
    */.agents/skills/obsidian-cli/*) continue ;;
    */.agents/skills/obsidian-markdown/*) continue ;;
  esac
  echo "→ $script"
  if ! shellcheck -x "$script"; then
    FAILED=$((FAILED + 1))
    echo "  ✗ FAILED"
  else
    echo "  ✓ OK"
  fi
done < <(find "$VAULT" -type f -name "*.sh" -not -path "*/node_modules/*" -print0)

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "$FAILED script(s) failed shellcheck."
  exit 1
fi

echo ""
echo "✓ All scripts passed shellcheck"
exit 0
