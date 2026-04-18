# Atlas — LLM-Maintained Research Vault

An Obsidian vault template where an LLM agent does the bookkeeping of a research wiki, so you can focus on curating sources and asking good questions. Based on [Andrej Karpathy's LLM-wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), extended with patterns from five community implementations.

**The core idea**: the tedious part of maintaining a knowledge base isn't reading or thinking — it's bookkeeping (cross-references, summaries, index upkeep, reconciling contradictions). LLMs don't experience tedium and can touch 15 files in one pass. The human curates what goes in; the agent handles the synthesis and upkeep. The wiki compounds: every new source strengthens existing pages, every answered query is filed back as a permanent page.

---

## What you get

- **Schema-first architecture.** `AGENTS.md` (symlinked to `CLAUDE.md`) defines every rule the agent follows: ingest, query, lint, page conventions, frontmatter, cross-linking, provenance, confidence, source conflicts, page lifecycle, archival, crystallization.
- **Five vault-native skills** the LLM triggers by natural language:
  - `vault-ingest` — drop a source, get a Sources/Concepts/Entities network
  - `vault-query` — research questions synthesized with citations, optionally filed as Outputs
  - `vault-review` — walk the `explored: false` human-review queue with judgment
  - `vault-maintain` — lint, crystallize, promote lifecycle, archive
  - `vault-init` — scaffold a new vault from this template
- **Obsidian-native agent skills** vendored from [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills): markdown, bases, canvas, CLI, defuddle.
- **Six utility scripts** in `bin/`: quickstart walkthrough, severity-tiered lint, unlinked-mention finder, vault stats, review queue processor, yt-dlp wrapper.
- **Five page templates** wired into Obsidian's Templates plugin.
- **Custom CSS callouts** for contradictions, gaps, key insights, stale claims.
- **Vault Health dashboard** (`.base` file, 8 views) powered by Obsidian Bases.
- **File Hider plugin** pre-configured to hide plumbing folders from the file explorer.
- **Full test suite** — shellcheck, JSON/YAML schemas, bats integration tests, template-drift detection, wikilink validation, schema-sync, custom callout consistency. ~70 assertions, ~12s to run.

---

## Who it's for

- Researchers who want a personal knowledge base that doesn't rot
- Anyone who's tried and abandoned a wiki because maintenance grew faster than value
- Teams using an LLM (Claude, Codex, opencode) as a research collaborator
- Power users of Obsidian who want structure without a plugin-heavy setup

---

## Quickstart — Claude Code

1. **Clone the template**
   ```bash
   git clone https://github.com/syntheticrecon/atlas-obsidian-vault.git my-vault
   cd my-vault
   ```

2. **Disconnect from upstream history** (your vault owns its own history)
   ```bash
   rm -rf .git && git init && git add . && git commit -m "Initial vault"
   ```

3. **Install required tools** (most are optional; see [Tools & dependencies](#tools--dependencies))
   ```bash
   brew install yt-dlp jq ripgrep         # core utilities
   pip install pyyaml jsonschema           # for the test suite (optional)
   ```

4. **Open the guided walkthrough**
   ```bash
   bin/quickstart.sh
   ```

5. **Customize for your domain** — open `AGENTS.md`, find the *Domain Customization* section near the top, adjust page types / frontmatter fields / entity subtypes for your research domain (papers? recipes? product docs?).

6. **Drop your first source and ingest**
   ```bash
   # Web article:
   cp ~/Downloads/article.md raw/
   # YouTube:
   bin/yt-ingest.sh "https://youtube.com/watch?v=..."
   ```
   Then ask Claude: *"ingest the new source in raw/"* — the `vault-ingest` skill auto-triggers.

7. **Review what the agent created** — every AI-created page starts with `explored: false`.
   ```
   ask Claude: "review the queue"
   # or, bash menu mode:
   bin/review.sh
   ```

Claude Code auto-discovers skills from `.claude/skills/` (symlinks to `.agents/skills/`). `CLAUDE.md` → `AGENTS.md` is read automatically. No additional configuration needed.

---

## Quickstart — opencode

Atlas skills follow the [Agent Skills specification](https://agentskills.io/specification), so they work with opencode too.

1. **Clone the template** (same as above)

2. **Make skills discoverable**. opencode auto-discovers skills from `~/.opencode/skills/` globally and from `.opencode/skills/` per-project. The skills live in `.agents/skills/`; expose them to opencode by symlinking:

   ```bash
   mkdir -p .opencode/skills
   for skill in .agents/skills/*/; do
     name=$(basename "$skill")
     ln -sf "../../.agents/skills/$name" ".opencode/skills/$name"
   done
   ```

   (The template already does this for Claude Code at `.claude/skills/`.)

3. **Point opencode at AGENTS.md**. opencode reads `AGENTS.md` (or `CLAUDE.md`) automatically as the project instructions file.

4. **Run the guided walkthrough and customize**, same as the Claude Code flow:
   ```bash
   bin/quickstart.sh
   # edit AGENTS.md → Domain Customization section
   ```

5. **Ingest your first source** and trigger skills by natural language the same way.

---

## Tools & dependencies

### Required for ingestion and review

| Tool | Install | Why |
|------|---------|-----|
| [Obsidian](https://obsidian.md) | [download](https://obsidian.md/download) | The vault viewer |
| [Claude Code](https://claude.com/claude-code) or [opencode](https://github.com/opencode-ai/opencode) | see their docs | The LLM agent driving the workflows |
| `git` | OS default | Clone + version control the vault |
| Bash 3.2+ | OS default (macOS ships 3.2, Linux usually 5+) | Scripts in `bin/` |

### Recommended

| Tool | Install | Used for |
|------|---------|----------|
| [`yt-dlp`](https://github.com/yt-dlp/yt-dlp) | `brew install yt-dlp` | `bin/yt-ingest.sh` — YouTube transcripts |
| [`ripgrep`](https://github.com/BurntSushi/ripgrep) | `brew install ripgrep` | Fast search across the vault |
| [`jq`](https://jqlang.github.io/jq/) | `brew install jq` | Manifest queries, test suite |
| [Defuddle](https://github.com/kepano/defuddle) | `npm install -g defuddle` | Clean web pages to markdown before ingest |
| [agent-browser](https://github.com/vercel-labs/agent-browser) | `brew install agent-browser` then `agent-browser install` | Programmatic web capture |
| [`qmd`](https://github.com/tobi/qmd) | see repo | Local search at 100+ pages (optional) |

### Optional — for running the test suite

| Tool | Install | Why |
|------|---------|-----|
| [`shellcheck`](https://github.com/koalaman/shellcheck) | `brew install shellcheck` | Static bash analysis |
| [`bats-core`](https://github.com/bats-core/bats-core) | `brew install bats-core` | Integration tests |
| Python 3 + PyYAML + jsonschema | `pip install pyyaml jsonschema` | Schema and frontmatter validation |

Run `tests/test.sh` to exercise everything; `tests/test.sh --fast` skips bats for a <1s run.

### Obsidian community plugins (ships with)

- [File Hider](https://github.com/Oliver-Akins/File-Hider) — hides `bin/`, `_templates/`, `tests/`, `AGENTS.md`, `README.md` from the file explorer so your view stays focused on research content. Uninstall it if you want full visibility.

---

## Documentation

- **[TUTORIAL.md](TUTORIAL.md)** — comprehensive human-facing guide (650+ lines, covers architecture, page types, workflows, frontmatter, cross-linking, provenance, source conflicts, lifecycle, rhythm, scaling, pitfalls, philosophy)
- **[AGENTS.md](AGENTS.md)** — agent-facing schema (the LLM reads this automatically)
- **[methodology/](methodology/)** — reference stubs linking to Karpathy's gist, X thread, and kepano's obsidian-skills
- **[tests/README.md](tests/README.md)** — test suite documentation
- **Skills**: `.agents/skills/vault-*/SKILL.md` — read any skill to see exactly what it does

---

## Platform notes

**Windows users**: this template uses symlinks (`CLAUDE.md → AGENTS.md` and `.claude/skills/* → .agents/skills/*`). Windows requires [Developer Mode enabled](https://learn.microsoft.com/en-us/windows/apps/get-started/enable-your-device-for-development) or `git config --global core.symlinks true` run in an admin shell. Otherwise symlinks are checked out as text files and skill discovery breaks. macOS and Linux work out of the box.

---

## Credits

- [Andrej Karpathy](https://x.com/karpathy) — the LLM-wiki pattern this template implements ([original gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f), [X thread](https://x.com/karpathy/status/2039805659525644595))
- [@kepano](https://github.com/kepano) — [obsidian-skills](https://github.com/kepano/obsidian-skills) (vendored as core Obsidian agent skills)
- [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) — web source capture
- [Oliver Akins](https://github.com/Oliver-Akins) — [File Hider](https://github.com/Oliver-Akins/File-Hider)
- Community implementations studied during design: [second-brain](https://github.com/NicholasSpisak/second-brain), [claude-obsidian](https://github.com/AgriciDaniel/claude-obsidian), [obsidian-wiki](https://github.com/Ar9av/obsidian-wiki), [llm-wikid](https://github.com/shannhk/llm-wikid), [llm-knowledge-base-template](https://github.com/zerowing113/llm-knowledge-base-template)

---

## License

MIT — see [LICENSE](LICENSE).
