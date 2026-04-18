#!/bin/bash
# vault-health.sh — Severity-tiered lint for the research vault.
# Usage: bin/vault-health.sh [vault-path]
#
# Defaults to current directory if no path given. Runs cleanly on empty vault.

set -u

VAULT="${1:-.}"
WIKI_DIRS=(Sources Concepts Entities Questions Outputs)

cd "$VAULT" 2>/dev/null || { echo "ERROR: cannot cd to $VAULT"; exit 1; }

# Header
echo "=== Vault Health Check ==="
echo "Vault: $(pwd)"
echo ""

# Build list of existing wiki dirs
existing_dirs=()
for d in "${WIKI_DIRS[@]}"; do
  [ -d "$d" ] && existing_dirs+=("$d")
done

if [ ${#existing_dirs[@]} -eq 0 ]; then
  echo "INFO: No wiki folders exist yet (Sources/, Concepts/, etc.). Vault is in template state."
  echo ""
  echo "=== Health check complete ==="
  exit 0
fi

# ----- ERRORS -----
echo "--- ERRORS ---"

# Build set of all wiki page names (sans .md)
pages_file="$(mktemp)"
trap 'rm -f "$pages_file"' EXIT
for d in "${existing_dirs[@]}"; do
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    basename "$f" .md >> "$pages_file"
  done
done

# Broken wikilinks: links to pages that don't exist
for d in "${existing_dirs[@]}"; do
  rg --no-filename --no-line-number -o '\[\[([^\]|#]+)' -r '$1' "$d" 2>/dev/null \
    | sort -u \
    | while read -r link; do
      # Strip path prefixes if any (e.g., Outputs/Page → Page)
      target=$(basename "$link")
      if ! grep -qx "$target" "$pages_file" 2>/dev/null; then
        echo "  BROKEN LINK: [[$link]]"
      fi
    done
done

# Missing status frontmatter
# Required on Concepts/, Entities/, Questions/, Outputs/ — not on Sources/
for d in "${existing_dirs[@]}"; do
  # Sources/ pages don't require status per the schema
  [ "$d" = "Sources" ] && continue
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    if ! awk '/^---$/{c++; if(c==2) exit} c==1 && /^status:/' "$f" | grep -q .; then
      echo "  MISSING status: $f"
    fi
  done
done

echo ""
echo "--- WARNINGS ---"

# Orphans: pages with no inbound wikilinks from other wiki pages.
# Links may appear as [[Name]], [[Folder/Name]], [[Name|display]], or [[Name#heading]].
for d in "${existing_dirs[@]}"; do
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    found=0
    for d2 in "${existing_dirs[@]}"; do
      # Match [[Name]], [[anything/Name]], with optional |display or #heading suffix
      if rg -q "\[\[(?:[^\]|#]*/)?${name}(\||\#|\])" "$d2" --glob "!$f" 2>/dev/null; then
        found=1
        break
      fi
    done
    [ $found -eq 0 ] && echo "  ORPHAN: $f"
  done
done

# Pages with zero outgoing wikilinks
for d in "${existing_dirs[@]}"; do
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    if ! rg -q "\[\[" "$f" 2>/dev/null; then
      echo "  NO OUTGOING LINKS: $f"
    fi
  done
done

echo ""
echo "--- INFO ---"

# Pages with explored: false
for d in "${existing_dirs[@]}"; do
  rg -l "^explored: false" "$d" 2>/dev/null | while read -r f; do
    echo "  NEEDS REVIEW: $f"
  done
done

# Seed-status pages
for d in "${existing_dirs[@]}"; do
  rg -l "^status: seed" "$d" 2>/dev/null | while read -r f; do
    echo "  SEED: $f"
  done
done

# Concepts/Entities missing aliases
for d in Concepts Entities; do
  [ -d "$d" ] || continue
  for f in "$d"/*.md; do
    [ -f "$f" ] || continue
    if ! awk '/^---$/{c++; if(c==2) exit} c==1 && /^aliases:/' "$f" | grep -q .; then
      echo "  MISSING aliases: $f"
    fi
  done
done

echo ""
echo "=== Health check complete ==="
