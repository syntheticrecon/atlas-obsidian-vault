#!/bin/bash
# cross-linker.sh — Find unlinked mentions of known wiki pages.
# Usage: bin/cross-linker.sh [vault-path]

set -u

VAULT="${1:-.}"
WIKI_DIRS=(Sources Concepts Entities Questions Outputs)
MIN_NAME_LEN=4

cd "$VAULT" 2>/dev/null || { echo "ERROR: cannot cd to $VAULT"; exit 1; }

echo "=== Cross-Link Scan ==="
echo "Vault: $(pwd)"
echo ""

# Collect existing wiki dirs and pages
existing_dirs=()
for d in "${WIKI_DIRS[@]}"; do
  [ -d "$d" ] && existing_dirs+=("$d")
done

if [ ${#existing_dirs[@]} -eq 0 ]; then
  echo "INFO: No wiki folders exist yet. Nothing to scan."
  exit 0
fi

# Gather page names
pages=()
for d in "${existing_dirs[@]}"; do
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    [ ${#name} -ge $MIN_NAME_LEN ] && pages+=("$name|$f")
  done
done

if [ ${#pages[@]} -eq 0 ]; then
  echo "INFO: No wiki pages found. Nothing to scan."
  exit 0
fi

found_any=0
for entry in "${pages[@]}"; do
  name="${entry%%|*}"
  src="${entry##*|}"

  for d in "${existing_dirs[@]}"; do
    while IFS= read -r f; do
      [ "$f" = "$src" ] && continue
      # Mention exists; check if any wikilink to this name exists in the file
      if rg -q -F "$name" "$f" 2>/dev/null && ! rg -q "\[\[${name}(\||\#|\])" "$f" 2>/dev/null; then
        echo "  UNLINKED: '$name' mentioned in $f"
        found_any=1
      fi
    done < <(rg -l -F "$name" "$d" 2>/dev/null)
  done
done

[ $found_any -eq 0 ] && echo "  No unlinked mentions found."

echo ""
echo "=== Scan complete ==="
