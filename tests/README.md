# Vault Test Suite

Rigorous testing for the vault's orchestration, scripts, JSON, and schemas.

## Quick start

```bash
tests/test.sh           # full suite (static + schemas + bats integration)
tests/test.sh --fast    # skip bats, only static + schema validation (~1s)
```

## Dependencies

Required (most checks will skip gracefully if missing):

| Tool | Install | What it does |
|------|---------|--------------|
| `python3` + `PyYAML` + `jsonschema` | `pip install pyyaml jsonschema` | Frontmatter + JSON schema validation |
| `shellcheck` | `brew install shellcheck` | Static analysis of bash scripts |
| `jq` | `brew install jq` | JSON syntax validation |
| `bats-core` | `brew install bats-core` | Integration tests |

## What gets tested

### Layer 1: Static analysis (`tests/lint/`)

- `shellcheck-all.sh` — runs shellcheck on every `.sh` in the vault (skipping vendored skills). Catches quoting bugs, undefined vars, portability issues.
- `validate-json.sh` — every `.json` and `.base` file parses cleanly via `jq`.

### Layer 2: Schema validation (`tests/lint/validate.py`)

Validates:

- **Required files exist**: AGENTS.md, CLAUDE.md symlink, hot.md, TUTORIAL.md, index.md, log.md, manifest, appearance snippet, CSS, all 3 bin/ scripts, Vault Health.base
- **Symlink integrity**: CLAUDE.md → AGENTS.md
- **CSS snippet enabled**: `wiki-callouts` in `.obsidian/appearance.json`
- **Scripts executable**: `chmod +x` applied to bin/*.sh
- **Bash 3.2 compatibility**: no `mapfile`/`readarray`/`declare -A`/case-conversion in `/bin/bash` shebangs
- **Manifest schema**: `raw/.manifest.json` matches `tests/schemas/manifest.schema.json`
- **Settings schema**: `.claude/settings.json` matches `tests/schemas/settings.schema.json`
- **Template correctness**: all 5 templates exist and have valid frontmatter; Concept template has Counter-arguments + Data Gaps sections
- **Page frontmatter**: every page in Sources/, Concepts/, Entities/, Questions/, Outputs/ matches its schema
- **Mandatory sections**: Concept/ pages have Counter-arguments and Data Gaps headers
- **`.base` file structure**: top-level keys, view types, formula syntax, referenced frontmatter fields

Schema definitions live in `tests/schemas/`:

- `manifest.schema.json` — delta tracking manifest
- `settings.schema.json` — Claude Code settings.json
- `frontmatter.schema.json` — per-page-type frontmatter (Source, Concept, Entity, Question, Output)

### Layer 2b: Cross-cutting lint

- **`validate-wikilinks.py`** — scans every `.md` file (incl. docs like `AGENTS.md`, `TUTORIAL.md`, `index.md`, `hot.md`), strips fenced code blocks and inline code, and verifies every `[[wikilink]]` resolves to a page or alias. Folder-style links (`[[raw/]]`) resolve to existing folders.
- **`check-schema-sync.py`** — parses the "Recommended Frontmatter Schema" table in `AGENTS.md` and cross-checks it against `frontmatter.schema.json` and each template. Catches drift between prose, code, and scaffold.
- **`check-callouts.py`** — enforces that every custom callout (`> [!name]`) used in markdown has a corresponding `.callout[data-callout="name"]` rule in `.obsidian/snippets/wiki-callouts.css`. Built-in Obsidian callouts are allowed without a rule. Reverse direction (CSS rule without usage) is a warning.

### Layer 3: Integration tests (`tests/integration/*.bats`)

**`vault-init.bats`** — end-to-end vault-init flow:

- Script is executable
- Refuses to overwrite existing path
- Creates new vault successfully
- Does NOT pre-create wiki folders (create-on-demand principle)
- Uses `methodology/` not `reference/`
- Has all required root files
- CLAUDE.md symlink resolves correctly
- All 5 templates present
- bin/ scripts executable
- CSS snippet installed and enabled
- manifest.json is valid
- raw/assets directory created
- vault-health.sh runs cleanly on empty vault
- cross-linker.sh runs cleanly on empty vault
- yt-ingest.sh shows usage on no args

**`scripts.bats`** — bin/ scripts under realistic conditions:

- `vault-health.sh` detects broken wikilinks
- `vault-health.sh` detects missing `status` frontmatter
- `vault-health.sh` surfaces `explored: false` pages as INFO
- `cross-linker.sh` finds unlinked mentions
- `cross-linker.sh` skips names shorter than 4 chars
- `yt-ingest.sh` exits with usage when missing URL
- `yt-ingest.sh` rejects unknown flags
- `yt-ingest.sh` does NOT use bash 4+ `mapfile`/`readarray`

**`vault-init-diff.bats`** — template-drift detection:

- Every verbatim-copied file (AGENTS.md, TUTORIAL.md, templates, CSS, bin scripts, Vault Health.base, manifest, methodology) has an identical hash in the generated vault
- Generated files (hot.md, index.md, log.md) contain all required sections
- CLAUDE.md symlink resolves correctly
- `.claude/settings.json`, `skills-lock.json`, wiki content folders are NOT copied

**`ingest-simulation.bats`** — end-to-end ingest invariants using `tests/fixtures/ingest-simulation/`:

- Fixture source file is hashed and tracked in `raw/.manifest.json`
- Expected Sources/Concepts/Entities pages exist
- Bidirectional cross-links exist (Sources ↔ Concepts ↔ Entities)
- `index.md` references every new page
- `log.md` has a new ingest entry
- Concept pages include mandatory Counter-arguments + Data Gaps sections
- All AI-created pages start with `explored: false`
- `vault-health.sh` reports zero ERRORS
- `validate.py` passes on the result
- `validate-wikilinks.py` passes on the result

## Fixtures

`tests/fixtures/valid/` — known-good pages:
- `Source-valid.md`, `Concept-valid.md`

`tests/fixtures/invalid/` — pages that should fail validation:
- `Source-missing-type.md` — no `type:` field
- `Concept-bad-status.md` — typo `evergeen` (not in enum)
- `Concept-missing-sections.md` — no Counter-arguments section
- `manifest-bad.json` — malformed manifest

## When to run

- **Before every commit**: `tests/test.sh --fast` (~1 second)
- **After touching scripts or schemas**: `tests/test.sh` (full suite)
- **After adding a new page type or frontmatter field**: update `frontmatter.schema.json` first, then run
- **CI**: wire `tests/test.sh` into your CI job; exit code signals success

## Adding new tests

- **New schema check**: extend `tests/schemas/*.json`, validate.py picks it up automatically
- **New bash script**: shellcheck-all.sh scans it automatically; add a `scripts.bats` case for behavior
- **New integration flow**: add a `.bats` file under `tests/integration/`, orchestrator runs it

## Known gaps (still NOT closed)

These are documented so future work knows where to look:

- **yt-ingest.sh against real YouTube URLs** — requires network access, yt-dlp binary, and a deterministic fixture. Current tests only verify CLI contract (usage, unknown flags, bash 3.2 compat).
- **Performance/memory at 100+ pages** — scripts are tested on small vaults only. Unicode titles, very long files, and deeply nested folders are untested.
- **Concurrent or interrupted ingest atomicity** — manifest updates aren't transactional; two processes writing simultaneously could clobber each other. No test covers this.
- **Linux vs macOS portability** — all tests run on macOS. `find`, `sed`, `stat`, and `readlink` differ between BSD and GNU variants.
- **Claude Code hook firing** — we validate hook structure in settings.json but never observe a real session firing them.
- **Obsidian Bases filter/formula semantics at render time** — we validate top-level structure and referenced frontmatter fields but don't execute filter logic. A filter like `status == "seed"` with a field that exists but is misspelled won't be caught.
- **CSS custom callout visual rendering** — validator verifies the CSS rule exists; Obsidian applies it at render time. Requires running Obsidian to verify colors/icons.
- **skills-lock.json vs vendored skills consistency** — if someone updates `skills-lock.json` without re-vendoring, no test catches the mismatch.
- **External tool availability** — `defuddle`, `agent-browser`, `rg`, `yt-dlp` are assumed installed; no probe verifies their presence before AGENTS.md promises them.
