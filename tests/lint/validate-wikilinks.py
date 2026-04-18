#!/usr/bin/env python3
"""
Validate wikilinks across every .md file in the vault.

Strips fenced code blocks and inline code before scanning, so illustrative
examples in documentation prose don't produce false positives.

Usage:
    python3 tests/lint/validate-wikilinks.py [vault-path]

Exit codes:
    0 — all links resolve
    1 — one or more broken links
    2 — dependency missing
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(2)


VAULT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()

# Exclude vendored / external directories.
EXCLUDE_DIRS = {".agents", "node_modules", ".git", ".obsidian", "tests/fixtures/invalid"}


FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
FENCE_RE = re.compile(r"```.*?```", re.DOTALL)
INLINE_CODE_RE = re.compile(r"`[^`\n]+`")
WIKILINK_RE = re.compile(r"\[\[([^\]]+)\]\]")


def is_excluded(path: Path) -> bool:
    rel_parts = path.relative_to(VAULT).parts
    for part in rel_parts:
        if part in EXCLUDE_DIRS:
            return True
    # Exclude ALL test fixtures — they intentionally contain dangling links
    rel = path.relative_to(VAULT).as_posix()
    if rel.startswith("tests/fixtures/"):
        return True
    return False


def collect_md_files() -> list[Path]:
    files = []
    for p in VAULT.rglob("*.md"):
        if not is_excluded(p):
            files.append(p)
    return sorted(files)


def extract_frontmatter(path: Path) -> dict | None:
    try:
        content = path.read_text()
    except Exception:
        return None
    m = FRONTMATTER_RE.match(content)
    if not m:
        return None
    try:
        data = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return None
    if isinstance(data, dict):
        return data
    return None


def strip_code(text: str) -> str:
    """Remove fenced code blocks and inline code spans."""
    text = FENCE_RE.sub("", text)
    text = INLINE_CODE_RE.sub("", text)
    return text


def page_basename(path: Path) -> str:
    return path.stem


def build_target_index(md_files: list[Path]) -> tuple[set[str], dict[str, list[str]]]:
    """
    Return (basenames, alias_to_pages).
    basenames: every .md filename stem (resolves [[Name]] to Name.md anywhere)
    alias_to_pages: every aliases: entry → list of pages that declare it
    """
    basenames: set[str] = set()
    alias_to_pages: dict[str, list[str]] = {}

    for p in md_files:
        basenames.add(page_basename(p))
        fm = extract_frontmatter(p)
        if not fm:
            continue
        aliases = fm.get("aliases")
        if not aliases:
            continue
        if isinstance(aliases, str):
            aliases = [aliases]
        if not isinstance(aliases, list):
            continue
        for a in aliases:
            if not isinstance(a, str):
                continue
            alias_to_pages.setdefault(a, []).append(p.relative_to(VAULT).as_posix())

    return basenames, alias_to_pages


def build_folder_set() -> set[str]:
    """Return all folder paths (ending with /) so [[raw/]] resolves."""
    folders: set[str] = set()
    for p in VAULT.rglob("*"):
        if p.is_dir() and not is_excluded(p):
            rel = p.relative_to(VAULT).as_posix()
            folders.add(rel)
            folders.add(rel + "/")
    return folders


def normalize_target(raw: str) -> str:
    """Strip display text (| or \\|) and block/heading refs (#)."""
    target = raw
    # Obsidian allows escaped pipe `\|` in tables; treat same as plain `|`
    target = target.replace("\\|", "|")
    if "|" in target:
        target = target.split("|", 1)[0]
    if "#" in target:
        target = target.split("#", 1)[0]
    return target.strip()


def resolve(target: str, basenames: set[str], aliases: dict, folders: set[str]) -> str:
    """
    Return resolution kind:
        "page"   — matches a wiki page basename
        "alias"  — matches an alias
        "folder" — matches a folder path (e.g. "raw/")
        "empty"  — target string is empty
        "miss"   — doesn't resolve
    """
    if not target:
        return "empty"

    # Handle path-style targets: strip leading folder if present
    # [[Outputs/Proposal]] resolves if Proposal is in Outputs/
    path_part = target
    name = target.rsplit("/", 1)[-1]

    if path_part in folders:
        return "folder"
    if target.endswith("/"):
        # Folder reference that didn't match
        return "miss"

    if name in basenames:
        return "page"
    if path_part in basenames:
        return "page"

    if target in aliases or name in aliases:
        return "alias"

    return "miss"


def main() -> int:
    md_files = collect_md_files()
    basenames, aliases = build_target_index(md_files)
    folders = build_folder_set()

    errors: list[str] = []
    alias_hits: list[str] = []
    total_links = 0

    print(f"Validating wikilinks in {len(md_files)} markdown files under {VAULT}")
    print()

    for path in md_files:
        try:
            text = path.read_text()
        except Exception as e:
            errors.append(f"READ FAILED: {path.relative_to(VAULT)} — {e}")
            continue

        # Strip frontmatter so we don't scan YAML as prose
        text = FRONTMATTER_RE.sub("", text, count=1)
        prose = strip_code(text)

        for match in WIKILINK_RE.finditer(prose):
            raw = match.group(1)
            target = normalize_target(raw)
            total_links += 1
            result = resolve(target, basenames, aliases, folders)
            if result == "miss":
                errors.append(f"BROKEN LINK: {path.relative_to(VAULT)} → [[{raw}]]")
            elif result == "empty":
                errors.append(f"EMPTY LINK: {path.relative_to(VAULT)}")
            elif result == "alias":
                alias_hits.append(f"{path.relative_to(VAULT)} → [[{raw}]] (via alias)")

    print(f"Scanned {total_links} wikilink(s) across {len(md_files)} file(s).")
    if alias_hits:
        print(f"\n{len(alias_hits)} link(s) resolved via alias:")
        for h in alias_hits[:20]:
            print(f"  ℹ {h}")
        if len(alias_hits) > 20:
            print(f"  … and {len(alias_hits) - 20} more")

    if errors:
        print(f"\n{len(errors)} ERROR(S):")
        for e in errors:
            print(f"  ✗ {e}")
        return 1

    print("\n✓ All wikilinks resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
