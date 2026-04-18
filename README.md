# LLM-Maintained Research Vault Template

An Obsidian vault template where an LLM agent maintains the wiki layer. You curate sources and ask questions; the agent handles the bookkeeping — summaries, cross-links, entity extraction, index and log upkeep. Based on [Karpathy's LLM-wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), extended with patterns from five community implementations.

## What this gives you

- **Schema** (`AGENTS.md` / `CLAUDE.md`): canonical rules for ingest, query, lint, page conventions, frontmatter, cross-linking, provenance, confidence, source conflicts, page lifecycle, archival, and crystallization.
- **Skills** (`.agents/skills/`): triggerable workflows the LLM invokes by name — `vault-ingest`, `vault-query`, `vault-review`, `vault-maintain`, `vault-init`.
- **Scripts** (`bin/`): `vault-health.sh` (lint), `cross-linker.sh` (unlinked mentions), `stats.sh` (vault metrics), `yt-ingest.sh` (YouTube transcripts), `review.sh` (review queue), `quickstart.sh` (first-run walkthrough).
- **Templates** (`_templates/`): scaffold pages for Source, Concept, Entity, Question, Output.
- **Tests** (`tests/`): 70+ assertions covering schema validation, JSON parsing, shellcheck, bash portability, wikilink integrity, ingest invariants, vault-init drift, custom callouts CSS, schema sync.
- **Obsidian config**: Bases, Canvas, Properties, Backlinks enabled; custom callouts styled (`contradiction`, `gap`, `key-insight`, `stale`).

## Quickstart

### 1. Clone this template

```bash
git clone https://github.com/<you>/<this-repo>.git my-research-vault
cd my-research-vault
```

Alternatively, fork the repo on GitHub and clone your fork.

### 2. Make it yours

Remove the link to the upstream template's history (your vault owns its own history):

```bash
rm -rf .git
git init
git add .
git commit -m "Initial vault from template"
```

Open `AGENTS.md` and customize the **Domain Customization** section for your domain (ML papers, recipes, product docs, etc.).

### 3. Run the guided walkthrough

```bash
bin/quickstart.sh
```

### 4. Ingest your first source

```bash
# Put any source in raw/:
cp ~/Downloads/interesting-paper.md raw/
# or for a YouTube video:
bin/yt-ingest.sh "https://youtube.com/watch?v=..."

# Then ask Claude/your LLM agent:
#   "Ingest the new source in raw/"
```

The `vault-ingest` skill takes over — reads the source, creates `Sources/<Title>.md`, extracts Concepts/Entities, cross-links everything, updates index and log.

### 5. Review what the agent created

```bash
# In Claude: "Review the queue"
# or for a bash menu:
bin/review.sh
```

Every AI-created page starts with `explored: false`. You flip it to `true` after reviewing. This is the staged-autonomy trust curve.

### 6. Query the wiki

Once you have a few sources ingested, ask research questions:

- "What do my sources say about X?"
- "Where do they disagree?"
- "Summarize Y and cite every source."

If the answer is worth keeping, ask: "File this as an Output." The answer becomes a permanent page that future queries reuse — this is the compounding mechanism.

### 7. Weekly maintenance

```bash
bin/stats.sh            # vault metrics
bin/vault-health.sh     # severity-tiered lint
bin/cross-linker.sh     # find unlinked mentions
```

Or ask Claude: "Maintain the wiki" — the `vault-maintain` skill handles it with judgment.

## Full documentation

- [`howto.md`](howto.md) — comprehensive human-facing guide
- [`AGENTS.md`](AGENTS.md) — agent-facing schema (CLAUDE.md symlinks to it)
- [`methodology/`](methodology/) — Karpathy's LLM-wiki thread and canonical pattern docs
- [`tests/README.md`](tests/README.md) — test suite documentation

## Required tools

**Required:**
- [Obsidian](https://obsidian.md) — the viewer
- Bash 3.2+ (macOS default) or Bash 4+

**Recommended:**
- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp) — video source ingest (`brew install yt-dlp`)
- [`rg` (ripgrep)](https://github.com/BurntSushi/ripgrep) — fast vault search (`brew install ripgrep`)
- [`jq`](https://jqlang.github.io/jq/) — JSON manipulation (`brew install jq`)
- [`defuddle`](https://github.com/kepano/defuddle) — clean web pages to markdown
- [`agent-browser`](https://github.com/vercel-labs/agent-browser) — browser automation for source capture

**For running tests:**
- `python3` with `pyyaml` and `jsonschema` (`pip install pyyaml jsonschema`)
- `shellcheck` (`brew install shellcheck`)
- `bats-core` (`brew install bats-core`)

## Running the test suite

```bash
tests/test.sh           # full suite (~12 seconds)
tests/test.sh --fast    # static + schema only (<1 second)
```

Tests are mainly useful if you're modifying the template itself (evolving the schema, adding skills, etc.). They're not required for day-to-day vault use.

## Credits

- [Karpathy's LLM-wiki thread](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — the foundational pattern
- [@kepano's obsidian-skills](https://github.com/kepano/obsidian-skills) — the Obsidian-native agent skills
- [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) — web source capture
- Community implementations studied: [second-brain](https://github.com/NicholasSpisak/second-brain), [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian), [obsidian-wiki](https://github.com/Ar9av/obsidian-wiki), [llm-wikid](https://github.com/shannhk/llm-wikid), [llm-knowledge-base-template](https://github.com/zerowing113/llm-knowledge-base-template)

## License

MIT — see [LICENSE](LICENSE).
