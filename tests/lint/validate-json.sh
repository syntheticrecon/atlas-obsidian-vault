#!/bin/bash
# validate-json.sh — verify every JSON file in the vault parses cleanly
# Does basic syntax validation only. Use validate.py for schema checks.

set -u

VAULT="${1:-.}"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not installed. Install with: brew install jq"
  exit 2
fi

FAILED=0
while IFS= read -r -d '' f; do
  case "$f" in
    */node_modules/*) continue ;;
  esac
  if jq empty "$f" >/dev/null 2>&1; then
    echo "  ✓ $f"
  else
    echo "  ✗ $f"
    jq empty "$f" 2>&1 | head -3 | sed 's/^/    /'
    FAILED=$((FAILED + 1))
  fi
done < <(find "$VAULT" -type f -name "*.json" -print0)

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "$FAILED JSON file(s) failed to parse."
  exit 1
fi

echo ""
echo "✓ All JSON files parse cleanly"
exit 0
