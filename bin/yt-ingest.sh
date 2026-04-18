#!/bin/bash
# yt-ingest.sh — Wrap yt-dlp to fetch a video/playlist transcript+metadata into raw/.
# Usage:
#   bin/yt-ingest.sh <url>
#   bin/yt-ingest.sh <playlist-url> [--limit N]
#
# Single videos and playlists are both supported. For playlists, each video
# becomes its own markdown file in raw/.

set -u

if [ $# -lt 1 ]; then
  echo "Usage: yt-ingest.sh <url> [--limit N]"
  exit 1
fi

URL="$1"
shift

LIMIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --limit) LIMIT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# Check yt-dlp installed
if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "ERROR: yt-dlp not found."
  echo "Install with: brew install yt-dlp"
  exit 1
fi

# Determine vault root (script lives in bin/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT_ROOT="$(dirname "$SCRIPT_DIR")"
RAW_DIR="$VAULT_ROOT/raw"
mkdir -p "$RAW_DIR"

slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g' \
    | cut -c1-80
}

ingest_one() {
  local url="$1"
  echo "→ Fetching: $url"

  # Get metadata
  local meta
  meta=$(yt-dlp --dump-json --no-warnings "$url" 2>/dev/null) || {
    echo "  ERROR: failed to fetch metadata for $url"
    return 1
  }

  # Parse all fields in a single Python call: cheaper and easier to read.
  # Formats upload_date as YYYY-MM-DD and duration as H:MM:SS.
  local parsed
  parsed=$(echo "$meta" | python3 -c '
import json, sys
d = json.load(sys.stdin)
title = d.get("title", "") or ""
channel = d.get("uploader", "") or d.get("channel", "") or ""
ud = d.get("upload_date", "") or ""
if len(ud) == 8 and ud.isdigit():
    ud = f"{ud[0:4]}-{ud[4:6]}-{ud[6:8]}"
dur = d.get("duration") or 0
try:
    dur = int(dur)
    h, rem = divmod(dur, 3600)
    m, s = divmod(rem, 60)
    dur_fmt = f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"
except (TypeError, ValueError):
    dur_fmt = d.get("duration_string", "") or ""
vid = d.get("id", "") or ""
# Emit one field per line; shell reads them with a readarray-equivalent loop
for val in (title, channel, ud, dur_fmt, vid):
    print(val)
')
  local title channel upload_date duration video_id
  {
    IFS= read -r title
    IFS= read -r channel
    IFS= read -r upload_date
    IFS= read -r duration
    IFS= read -r video_id
  } <<EOF
$parsed
EOF

  local slug
  slug=$(slugify "$title")
  [ -z "$slug" ] && slug="$video_id"

  local outfile="$RAW_DIR/${slug}.md"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  # Fetch subtitles to tmp
  yt-dlp --skip-download --write-auto-sub --sub-lang en --sub-format vtt \
    -o "$tmpdir/%(id)s.%(ext)s" --no-warnings "$url" >/dev/null 2>&1

  local vtt=""
  while IFS= read -r f; do vtt="$f"; break; done < <(find "$tmpdir" -maxdepth 1 -name "*.en.vtt" 2>/dev/null)

  {
    echo "---"
    echo "title: \"$title\""
    echo "type: video"
    echo "url: \"$url\""
    echo "channel: \"$channel\""
    echo "upload_date: \"$upload_date\""
    echo "duration: \"$duration\""
    echo "video_id: \"$video_id\""
    echo "---"
    echo ""
    echo "# $title"
    echo ""
    echo "**Channel:** $channel  "
    echo "**Uploaded:** $upload_date  "
    echo "**Duration:** $duration  "
    echo "**URL:** $url"
    echo ""
    echo "## Transcript"
    echo ""

    if [ -n "$vtt" ] && [ -f "$vtt" ]; then
      # Convert VTT to markdown: keep timestamps as ### headers, deduplicate
      awk '
        BEGIN { last=""; }
        /-->/ { ts=$1; sub(/\..*/, "", ts); next }
        /^WEBVTT/ || /^NOTE/ || /^$/ || /^Kind:/ || /^Language:/ { next }
        /^[0-9]+$/ { next }
        {
          gsub(/<[^>]+>/, "", $0)
          if ($0 != "" && $0 != last) {
            if (ts != "") { print "## [" ts "]"; ts="" }
            print $0
            last=$0
          }
        }
      ' "$vtt"
    else
      echo "*No transcript available.*"
    fi
  } > "$outfile"

  echo "  ✓ wrote $outfile"
}

# Detect playlist
if echo "$URL" | grep -q "list="; then
  echo "Detected playlist."

  entries=()
  while IFS= read -r line; do
    [ -n "$line" ] && entries+=("$line")
  done < <(yt-dlp --flat-playlist --print "%(url)s" --no-warnings "$URL" 2>/dev/null)

  count=${#entries[@]}
  if [ -n "$LIMIT" ] && [ "$LIMIT" -lt "$count" ]; then
    count="$LIMIT"
  fi

  echo "Processing $count videos..."
  i=0
  while [ "$i" -lt "$count" ]; do
    ingest_one "${entries[$i]}"
    i=$((i + 1))
  done
else
  ingest_one "$URL"
fi

echo ""
echo "Done. Files written to: $RAW_DIR"
