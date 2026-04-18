#!/usr/bin/env python3
"""
Enforce that every custom Obsidian callout used in vault markdown has a
corresponding CSS rule in .obsidian/snippets/wiki-callouts.css.

Custom callouts MUST be defined via CSS snippets with a specific
[data-callout="name"] selector. Built-in Obsidian callout names are allowed
without a CSS rule.

Usage:
    python3 tests/lint/check-callouts.py [vault-path]

Exit codes:
    0 — all custom callouts styled
    1 — one or more custom callouts missing CSS rules
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


VAULT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
SNIPPET = VAULT / ".obsidian" / "snippets" / "wiki-callouts.css"

# Per https://help.obsidian.md/Editing+and+formatting/Callouts — all built-ins
BUILTIN_CALLOUTS = {
    "note",
    "abstract", "summary", "tldr",
    "info",
    "todo",
    "tip", "hint", "important",
    "success", "check", "done",
    "question", "help", "faq",
    "warning", "caution", "attention",
    "failure", "fail", "missing",
    "danger", "error",
    "bug",
    "example",
    "quote", "cite",
}

EXCLUDE_DIRS = {".agents", "node_modules", ".git", ".obsidian"}

# > [!name] or > [!name]+ or > [!name]- with optional whitespace after >
# Captures the callout name (before closing bracket)
CALLOUT_RE = re.compile(r"^\s*>\s*\[!([a-z][a-z0-9-]*)\]", re.MULTILINE | re.IGNORECASE)

FENCE_RE = re.compile(r"```.*?```", re.DOTALL)
INLINE_CODE_RE = re.compile(r"`[^`\n]+`")

# Matches .callout[data-callout="name"] or [data-callout="name"]
CSS_SELECTOR_RE = re.compile(
    r'\[data-callout\s*=\s*"([a-z][a-z0-9-]*)"\]', re.IGNORECASE
)


def is_excluded(path: Path) -> bool:
    for part in path.relative_to(VAULT).parts:
        if part in EXCLUDE_DIRS:
            return True
    rel = path.relative_to(VAULT).as_posix()
    if rel.startswith("tests/fixtures/"):
        return True
    return False


def strip_code(text: str) -> str:
    text = FENCE_RE.sub("", text)
    text = INLINE_CODE_RE.sub("", text)
    return text


def collect_callout_usages() -> dict[str, list[str]]:
    """Return {callout_name: [files using it]} across all vault markdown."""
    usage: dict[str, list[str]] = {}
    for path in sorted(VAULT.rglob("*.md")):
        if is_excluded(path):
            continue
        try:
            text = path.read_text()
        except Exception:
            continue
        prose = strip_code(text)
        for m in CALLOUT_RE.finditer(prose):
            name = m.group(1).lower()
            usage.setdefault(name, []).append(path.relative_to(VAULT).as_posix())
    return usage


def collect_css_rules() -> set[str]:
    if not SNIPPET.exists():
        return set()
    try:
        css = SNIPPET.read_text()
    except Exception:
        return set()
    return {m.group(1).lower() for m in CSS_SELECTOR_RE.finditer(css)}


def main() -> int:
    if not SNIPPET.exists():
        print(f"ERROR: CSS snippet not found at {SNIPPET.relative_to(VAULT)}")
        print("Create .obsidian/snippets/wiki-callouts.css to define custom callouts.")
        return 1

    usage = collect_callout_usages()
    defined = collect_css_rules()

    print(f"Scanned callouts in markdown and CSS under {VAULT}")
    print(f"CSS rules defined:  {sorted(defined) or '(none)'}")
    print(f"Callouts used:      {sorted(usage.keys()) or '(none)'}")
    print()

    # Custom callouts = used minus built-in
    custom_used = set(usage.keys()) - BUILTIN_CALLOUTS

    errors: list[str] = []
    warnings: list[str] = []

    # Every custom callout must have a CSS rule
    for name in sorted(custom_used):
        if name not in defined:
            sample = usage[name][0]
            count = len(usage[name])
            errors.append(
                f"Custom callout [!{name}] used in {count} file(s) but no CSS rule exists. "
                f"Add `.callout[data-callout=\"{name}\"]` to {SNIPPET.relative_to(VAULT)}. "
                f"First usage: {sample}"
            )
        else:
            print(f"  ✓ [!{name}] — used in {len(usage[name])} file(s), styled")

    # CSS rules without usage: warn (might be staged for future use)
    for name in sorted(defined - custom_used):
        if name in BUILTIN_CALLOUTS:
            # Custom styling of a built-in callout is fine; note it
            continue
        warnings.append(
            f"CSS rule for [!{name}] defined but no markdown usage found."
        )

    if warnings:
        print(f"\n{len(warnings)} WARNING(S):")
        for w in warnings:
            print(f"  ⚠ {w}")

    if errors:
        print(f"\n{len(errors)} ERROR(S):")
        for e in errors:
            print(f"  ✗ {e}")
        return 1

    print("\n✓ All custom callouts have matching CSS rules")
    return 0


if __name__ == "__main__":
    sys.exit(main())
