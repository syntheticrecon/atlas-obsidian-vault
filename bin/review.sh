#!/bin/bash
# review.sh — Walk through pages with `explored: false` one at a time.
#
# Turns the "needs review" queue into an actual workflow: list pages the
# LLM created that a human hasn't verified, preview each one, then choose
# approve / skip / contest / edit / quit.
#
# Usage:
#   bin/review.sh              # interactive
#   bin/review.sh --list       # just list the queue (non-interactive)
#   bin/review.sh --count      # print the queue size
#   bin/review.sh [vault-path] # review against a specific vault

set -u

MODE="interactive"
VAULT="."
for arg in "$@"; do
  case "$arg" in
    --list)  MODE="list" ;;
    --count) MODE="count" ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) VAULT="$arg" ;;
  esac
done

cd "$VAULT" 2>/dev/null || { echo "ERROR: cannot cd to $VAULT"; exit 1; }

# Collect explored: false pages from Sources/, Concepts/, Entities/
queue=()
for dir in Sources Concepts Entities; do
  [ -d "$dir" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] && queue+=("$f")
  done < <(rg -l "^explored: false" "$dir" 2>/dev/null | sort)
done

count=${#queue[@]}

case "$MODE" in
  count)
    echo "$count"
    exit 0
    ;;
  list)
    if [ "$count" -eq 0 ]; then
      echo "Review queue is empty."
      exit 0
    fi
    echo "Review queue ($count page(s)):"
    for f in "${queue[@]}"; do
      echo "  • $f"
    done
    exit 0
    ;;
esac

# Interactive mode
if [ "$count" -eq 0 ]; then
  echo "Review queue is empty — nothing pending."
  exit 0
fi

echo "===================="
echo "Review queue: $count page(s) pending"
echo "===================="
echo ""

approved=0
skipped=0
contested=0
edited=0

idx=0
for page in "${queue[@]}"; do
  idx=$((idx + 1))
  clear 2>/dev/null || echo ""
  echo "────────────────────────────────────────────────────────────"
  echo "Page $idx of $count: $page"
  echo "────────────────────────────────────────────────────────────"
  echo ""
  # Show frontmatter and first 40 lines of body
  head -50 "$page"
  body_total=$(wc -l < "$page" | tr -d ' ')
  if [ "$body_total" -gt 50 ]; then
    echo ""
    echo "… ($((body_total - 50)) more lines not shown)"
  fi
  echo ""
  echo "────────────────────────────────────────────────────────────"
  echo "  [a] approve (explored: true)    [s] skip (leave as-is)"
  echo "  [c] contest (add review note)   [e] edit in \$EDITOR"
  echo "  [q] quit review session"
  echo "────────────────────────────────────────────────────────────"
  printf "Action: "
  read -r action
  echo ""

  case "$action" in
    a|A|approve)
      # Replace `explored: false` with `explored: true`
      tmp=$(mktemp)
      awk '/^explored: false$/{print "explored: true"; next} {print}' "$page" > "$tmp" && mv "$tmp" "$page"
      echo "✓ Approved: $page"
      approved=$((approved + 1))
      ;;
    s|S|skip|"")
      echo "⊘ Skipped."
      skipped=$((skipped + 1))
      ;;
    c|C|contest)
      printf "Contest note: "
      read -r note
      # Append a > [!question] Contested callout to the page
      {
        echo ""
        echo "> [!question] Contested (review $(date +%Y-%m-%d))"
        echo "> ${note:-See review queue}"
      } >> "$page"
      echo "✓ Added contest note to $page (still explored: false)"
      contested=$((contested + 1))
      ;;
    e|E|edit)
      "${EDITOR:-vi}" "$page"
      echo "✓ Edited. Leaving explored: false for follow-up review."
      edited=$((edited + 1))
      ;;
    q|Q|quit)
      echo "Session ended early."
      break
      ;;
    *)
      echo "Unknown action. Skipping."
      skipped=$((skipped + 1))
      ;;
  esac
  echo ""
done

echo ""
echo "===================="
echo "Review session summary"
echo "===================="
echo "  Approved:  $approved"
echo "  Skipped:   $skipped"
echo "  Contested: $contested"
echo "  Edited:    $edited"
remaining=$((count - approved - contested))
echo "  Remaining in queue: $remaining"
