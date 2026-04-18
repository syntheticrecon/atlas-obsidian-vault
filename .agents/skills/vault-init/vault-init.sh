#!/bin/bash
# vault-init — Create a new research vault by duplicating this template.
#
# This is a thin wrapper around `cp -r`: it copies the template verbatim, then
# clears user-generated content and per-session files so the new vault starts
# in a pristine state.
#
# Template state is the single source of truth. There is NO hardcoded content
# in this script — everything comes from the template directory. Edit the
# template (hot.md, index.md, log.md, etc.) and new vaults pick it up.
#
# Usage:
#   vault-init <new-vault-path>

set -e

TEMPLATE_VAULT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

if [ -z "${1-}" ]; then
    echo "Usage: vault-init <new-vault-path>"
    exit 1
fi

VAULT_PATH="$1"

if [ -e "$VAULT_PATH" ]; then
    echo "Error: $VAULT_PATH already exists"
    exit 1
fi

echo "Initializing vault at: $VAULT_PATH"
echo "  Source: $TEMPLATE_VAULT_DIR"
echo ""

# 1. Duplicate the template verbatim. Preserves symlinks (CLAUDE.md, .claude/skills/*)
#    and executable bits on bin/ scripts.
cp -RP "$TEMPLATE_VAULT_DIR" "$VAULT_PATH"

# Safety: VAULT_PATH is required above and non-empty, but guard against any
# future refactor that might leave it unset.
: "${VAULT_PATH:?VAULT_PATH must be set}"

# 2. Clear user-generated content. Wiki folders (Sources/, Concepts/, etc.)
#    are created on demand during first ingest — don't carry over from the template.
for dir in Sources Concepts Entities Questions Outputs; do
    rm -rf "${VAULT_PATH:?}/$dir"
done

# 3. Clear raw content but preserve the structure (assets dir + empty manifest).
find "${VAULT_PATH:?}/raw" -mindepth 1 -maxdepth 1 ! -name assets ! -name .manifest.json -exec rm -rf {} +

# 4. Clear per-session / per-dev artifacts that shouldn't propagate.
rm -f "${VAULT_PATH:?}/.claude/settings.local.json"
rm -rf "${VAULT_PATH:?}/.git"

# 5. Reset the delta manifest (if the template's got stale entries for any reason).
cat > "$VAULT_PATH/raw/.manifest.json" <<'EOF'
{
  "version": 1,
  "description": "Tracks raw source files and their wiki derivatives. Check before ingest to skip unchanged sources. Schema per entry: sha256 (content hash), ingested_at (ISO timestamp), wiki_pages (array of paths created/updated), status (current|updated|superseded).",
  "sources": {}
}
EOF

echo "Vault initialized at: $VAULT_PATH"
echo ""
echo "Next steps:"
echo "  1. cd $VAULT_PATH"
echo "  2. Open in Obsidian"
echo "  3. Run: bin/quickstart.sh  — guided walkthrough"
echo "  4. Customize the 'Domain Customization' section in AGENTS.md"
echo "  5. Drop your first source into raw/ and ingest"
