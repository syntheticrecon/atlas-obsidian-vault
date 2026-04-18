#!/bin/bash
# stats.sh — Summarize vault activity and compounding.
#
# The wiki's value is supposed to compound over time. This script makes that
# visible: count sources, pages by type and status, review velocity, and
# operation log summary. Run weekly to see whether the vault is growing and
# maturing, not just accumulating.
#
# Usage:
#   bin/stats.sh [vault-path]

set -u

VAULT="${1:-.}"
cd "$VAULT" 2>/dev/null || { echo "ERROR: cannot cd to $VAULT"; exit 1; }

echo "═════════════════════════════════════════════════════"
echo "Vault Stats: $(pwd | sed "s|$HOME|~|")"
echo "═════════════════════════════════════════════════════"
echo ""

# ---------- Page counts by folder ----------
echo "━━ Page counts ━━"
total=0
for dir in Sources Concepts Entities Questions Outputs; do
  if [ -d "$dir" ]; then
    count=$(find "$dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    printf "  %-10s %4d\n" "$dir/" "$count"
    total=$((total + count))
  else
    printf "  %-10s %4s\n" "$dir/" "—"
  fi
done
printf "  %-10s %4d\n" "TOTAL" "$total"
echo ""

# ---------- Status distribution (Concepts + Entities) ----------
if [ -d "Concepts" ] || [ -d "Entities" ]; then
  echo "━━ Concept/Entity lifecycle ━━"
  for status in seed developing mature evergreen superseded; do
    count=$(rg -l "^status: $status" Concepts Entities 2>/dev/null | wc -l | tr -d ' ')
    printf "  %-12s %3d\n" "$status" "$count"
  done
  echo ""
fi

# ---------- Review queue ----------
echo "━━ Human review ━━"
pending=0
reviewed=0
for dir in Sources Concepts Entities; do
  [ -d "$dir" ] || continue
  pending=$((pending + $(rg -l "^explored: false" "$dir" 2>/dev/null | wc -l | tr -d ' ')))
  reviewed=$((reviewed + $(rg -l "^explored: true" "$dir" 2>/dev/null | wc -l | tr -d ' ')))
done
printf "  Reviewed (explored: true):  %3d\n" "$reviewed"
printf "  Pending  (explored: false): %3d\n" "$pending"
if [ $((reviewed + pending)) -gt 0 ]; then
  pct=$(( reviewed * 100 / (reviewed + pending) ))
  printf "  Review velocity:            %3d%%\n" "$pct"
fi
echo ""

# ---------- Confidence distribution ----------
if [ -d "Concepts" ] || [ -d "Entities" ]; then
  echo "━━ Confidence ━━"
  for level in high medium low; do
    count=$(rg -l "^confidence: $level" Concepts Entities 2>/dev/null | wc -l | tr -d ' ')
    printf "  %-8s %3d\n" "$level" "$count"
  done
  echo ""
fi

# ---------- Open questions ----------
if [ -d "Questions" ]; then
  echo "━━ Open questions ━━"
  for state in open investigating resolved; do
    count=$(rg -l "^status: $state" Questions 2>/dev/null | wc -l | tr -d ' ')
    printf "  %-14s %3d\n" "$state" "$count"
  done
  echo ""
fi

# ---------- Link density ----------
echo "━━ Cross-link density ━━"
if [ "$total" -gt 0 ]; then
  link_count=$(rg -o "\[\[" Sources Concepts Entities Questions Outputs 2>/dev/null | wc -l | tr -d ' ')
  avg=$(( link_count / (total > 0 ? total : 1) ))
  printf "  Wikilinks total:    %4d\n" "$link_count"
  printf "  Pages total:        %4d\n" "$total"
  printf "  Links per page:     %4d\n" "$avg"
else
  echo "  (no wiki pages yet)"
fi
echo ""

# ---------- Log activity ----------
if [ -f "log.md" ]; then
  echo "━━ Log activity ━━"
  # Count operation types in log.md
  for op in ingest query update lint; do
    count=$(rg -c "^## \[[0-9-]+\] $op" log.md 2>/dev/null || echo "0")
    printf "  %-8s %3d\n" "$op:" "$count"
  done

  # Most recent entries
  echo ""
  echo "  Most recent:"
  rg -n "^## \[[0-9-]+\]" log.md 2>/dev/null | tail -5 | sed 's/^/    /'
  echo ""
fi

# ---------- Raw sources ingested ----------
if [ -f "raw/.manifest.json" ] && command -v jq >/dev/null 2>&1; then
  echo "━━ Delta manifest ━━"
  tracked=$(jq '.sources | length' raw/.manifest.json 2>/dev/null || echo 0)
  current=$(jq '[.sources[] | select(.status == "current")] | length' raw/.manifest.json 2>/dev/null || echo 0)
  superseded=$(jq '[.sources[] | select(.status == "superseded")] | length' raw/.manifest.json 2>/dev/null || echo 0)
  printf "  Tracked sources:    %3d\n" "$tracked"
  printf "  Current:            %3d\n" "$current"
  printf "  Superseded:         %3d\n" "$superseded"
  echo ""
fi

echo "═════════════════════════════════════════════════════"
