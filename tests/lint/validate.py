#!/usr/bin/env python3
"""
Validate JSON files and wiki page frontmatter against schemas.

Usage:
    python3 tests/lint/validate.py [vault-path]
"""

from __future__ import annotations

import datetime
import json
import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

try:
    import jsonschema
except ImportError:
    print("ERROR: jsonschema not installed. Run: pip install jsonschema", file=sys.stderr)
    sys.exit(2)


VAULT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
TESTS_DIR = Path(__file__).resolve().parent.parent
SCHEMAS = TESTS_DIR / "schemas"

errors: list[str] = []
warnings: list[str] = []


def load_json(path: Path):
    try:
        with open(path) as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        errors.append(f"INVALID JSON: {path} — {e}")
        return None
    except Exception as e:
        errors.append(f"READ FAILED: {path} — {e}")
        return None


def load_schema(name: str):
    return load_json(SCHEMAS / name)


def validate_json_file(path: Path, schema: dict, label: str):
    data = load_json(path)
    if data is None:
        return
    try:
        jsonschema.validate(instance=data, schema=schema)
        print(f"  ✓ {label}: {path.relative_to(VAULT)}")
    except jsonschema.ValidationError as e:
        errors.append(f"SCHEMA FAILED [{label}]: {path.relative_to(VAULT)} — {e.message} at path {'.'.join(str(p) for p in e.absolute_path)}")


FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


def extract_frontmatter(path: Path):
    try:
        content = path.read_text()
    except Exception as e:
        errors.append(f"READ FAILED: {path} — {e}")
        return None
    m = FRONTMATTER_RE.match(content)
    if not m:
        return None
    try:
        data = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError as e:
        errors.append(f"INVALID YAML FRONTMATTER: {path.relative_to(VAULT)} — {e}")
        return None
    return _stringify_dates(data)


def _stringify_dates(obj):
    """Convert date/datetime objects to ISO strings so they match schema 'string' types."""
    if isinstance(obj, dict):
        return {k: _stringify_dates(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_stringify_dates(v) for v in obj]
    if isinstance(obj, (datetime.date, datetime.datetime)):
        return obj.isoformat()
    return obj


def validate_wiki_pages(folder: str, schema_def: dict, required: bool):
    """Validate every .md page in the given folder against its frontmatter schema."""
    folder_path = VAULT / folder
    if not folder_path.is_dir():
        return
    for page in sorted(folder_path.glob("*.md")):
        fm = extract_frontmatter(page)
        if fm is None:
            if required:
                errors.append(f"MISSING FRONTMATTER: {page.relative_to(VAULT)}")
            continue
        try:
            jsonschema.validate(instance=fm, schema=schema_def)
            print(f"  ✓ {folder}/: {page.name}")
        except jsonschema.ValidationError as e:
            errors.append(
                f"FRONTMATTER INVALID [{folder}]: {page.relative_to(VAULT)} — "
                f"{e.message} at {'.'.join(str(p) for p in e.absolute_path) or 'root'}"
            )


def validate_concept_sections(page: Path):
    """Concept pages must have Counter-arguments and Data Gaps sections."""
    try:
        content = page.read_text()
    except Exception:
        return
    if "## Counter-arguments" not in content:
        warnings.append(f"CONCEPT MISSING 'Counter-arguments' section: {page.relative_to(VAULT)}")
    if "## Data Gaps" not in content and "## Data gaps" not in content:
        warnings.append(f"CONCEPT MISSING 'Data Gaps' section: {page.relative_to(VAULT)}")


def check_templates():
    """Templates must exist and have correct shape."""
    templates_dir = VAULT / "_templates"
    if not templates_dir.is_dir():
        errors.append("MISSING: _templates/ directory")
        return

    expected = {"Source.md", "Concept.md", "Entity.md", "Question.md", "Output.md"}
    found = {p.name for p in templates_dir.glob("*.md")}
    missing = expected - found
    extra = found - expected
    for m in missing:
        errors.append(f"MISSING TEMPLATE: _templates/{m}")
    for e in extra:
        warnings.append(f"EXTRA TEMPLATE: _templates/{e} (not in expected set)")

    # Validate each template's frontmatter
    schema_doc = load_schema("frontmatter.schema.json")
    if schema_doc:
        for name, key in [
            ("Source.md", "Source"),
            ("Concept.md", "Concept"),
            ("Entity.md", "Entity"),
            ("Question.md", "Question"),
            ("Output.md", "Output"),
        ]:
            path = templates_dir / name
            if not path.exists():
                continue
            fm = extract_frontmatter(path)
            if fm is None:
                errors.append(f"TEMPLATE MISSING FRONTMATTER: {path.relative_to(VAULT)}")
                continue
            try:
                jsonschema.validate(instance=fm, schema=schema_doc["definitions"][key])
                print(f"  ✓ template: {name}")
            except jsonschema.ValidationError as e:
                errors.append(f"TEMPLATE INVALID [{name}]: {e.message}")

        # Concept template specifically
        concept = templates_dir / "Concept.md"
        if concept.exists():
            validate_concept_sections(concept)


def check_symlink():
    claude = VAULT / "CLAUDE.md"
    if not claude.exists():
        errors.append("MISSING: CLAUDE.md symlink at vault root")
        return
    if not claude.is_symlink():
        warnings.append("CLAUDE.md is not a symlink (expected symlink → AGENTS.md)")
        return
    target = os.readlink(claude)
    if target != "AGENTS.md":
        warnings.append(f"CLAUDE.md symlink points to '{target}' (expected 'AGENTS.md')")
    else:
        print("  ✓ CLAUDE.md → AGENTS.md symlink")


def check_required_files():
    required = [
        "AGENTS.md", "index.md", "log.md", "hot.md", "TUTORIAL.md",
        "raw/.manifest.json", ".obsidian/appearance.json",
        ".obsidian/snippets/wiki-callouts.css",
        "bin/vault-health.sh", "bin/cross-linker.sh", "bin/yt-ingest.sh",
        "Vault Health.base",
    ]
    for rel in required:
        p = VAULT / rel
        if not p.exists():
            errors.append(f"MISSING: {rel}")
        else:
            print(f"  ✓ exists: {rel}")


def check_appearance_enables_snippet():
    path = VAULT / ".obsidian" / "appearance.json"
    data = load_json(path)
    if data is None:
        return
    snippets = data.get("enabledCssSnippets", [])
    if "wiki-callouts" not in snippets:
        errors.append(f"appearance.json: 'wiki-callouts' not in enabledCssSnippets (got {snippets})")
    else:
        print("  ✓ appearance.json enables wiki-callouts")


def check_scripts_executable():
    for name in ("vault-health.sh", "cross-linker.sh", "yt-ingest.sh"):
        p = VAULT / "bin" / name
        if not p.exists():
            continue
        if not os.access(p, os.X_OK):
            errors.append(f"NOT EXECUTABLE: bin/{name} (run chmod +x)")
        else:
            print(f"  ✓ executable: bin/{name}")


def check_bash_portability():
    """Guard against bash-4-only features on macOS default bash 3.2.

    Strips full-line and end-of-line comments (outside of heredocs and string
    literals) before pattern matching, and uses word boundaries for identifier
    builtins so mentions like "readarray-equivalent" in a comment don't trigger.
    """
    # (regex_pattern, description). Identifier-builtins use \b boundaries.
    bash4_only = [
        (r"\bmapfile\b", "mapfile", "mapfile is bash 4+; use a while-read loop"),
        (r"\breadarray\b", "readarray", "readarray is bash 4+; use a while-read loop"),
        (r"declare\s+-A\b", "declare -A", "associative arrays are bash 4+"),
        (r"\$\{[A-Za-z_][A-Za-z0-9_]*,,\}", "${var,,}", "lowercase conversion is bash 4+"),
        (r"\$\{[A-Za-z_][A-Za-z0-9_]*\^\^\}", "${var^^}", "uppercase conversion is bash 4+"),
    ]

    def strip_shell_comments(text: str) -> str:
        """Remove full-line and trailing comments (naive but sufficient).

        Heuristic: a `#` outside of single/double quotes starts a comment.
        This doesn't handle heredocs perfectly, but it's good enough for our
        bin/ scripts. Always preserves the shebang line verbatim.
        """
        out_lines = []
        for i, line in enumerate(text.splitlines()):
            if i == 0 and line.startswith("#!"):
                out_lines.append(line)
                continue
            # Walk characters, tracking quote state
            in_single = False
            in_double = False
            j = 0
            while j < len(line):
                ch = line[j]
                if ch == "\\" and not in_single and j + 1 < len(line):
                    j += 2
                    continue
                if ch == "'" and not in_double:
                    in_single = not in_single
                elif ch == '"' and not in_single:
                    in_double = not in_double
                elif ch == "#" and not in_single and not in_double:
                    # Comment starts; keep whatever came before
                    line = line[:j].rstrip()
                    break
                j += 1
            out_lines.append(line)
        return "\n".join(out_lines)

    any_errors = False
    for sh in (VAULT / "bin").glob("*.sh"):
        try:
            text = sh.read_text()
        except Exception:
            continue
        first_line = text.splitlines()[0] if text else ""
        if "bin/bash" not in first_line or "env bash" in first_line:
            continue  # shebang explicitly opts into newer bash
        code_only = strip_shell_comments(text)
        import re as _re
        for regex, display, msg in bash4_only:
            if _re.search(regex, code_only):
                errors.append(f"BASH COMPAT [{sh.relative_to(VAULT)}]: contains '{display}' — {msg}")
                any_errors = True

    if not any_errors:
        print("  ✓ bash 3.2 compatibility check")


def check_base_files():
    """Validate any .base file in the vault — top-level structure + referenced fields."""
    ALLOWED_TOP_LEVEL = {"filters", "formulas", "views", "properties", "displayName"}
    ALLOWED_VIEW_TYPES = {"table", "cards", "list", "board", "gallery"}
    schema_doc = load_schema("frontmatter.schema.json")
    known_fields = set()
    if schema_doc:
        for definition in schema_doc.get("definitions", {}).values():
            known_fields.update(definition.get("properties", {}).keys())
    # Plus Bases built-ins
    bases_reserved = {"file", "formula", "folder", "name", "mtime", "ctime", "path", "tags"}

    for base_path in VAULT.rglob("*.base"):
        rel = base_path.relative_to(VAULT)
        try:
            text = base_path.read_text()
            data = yaml.safe_load(text)
        except Exception as e:
            errors.append(f"BASE PARSE FAILED: {rel} — {e}")
            continue

        if not isinstance(data, dict):
            errors.append(f"BASE TOP-LEVEL MUST BE A MAPPING: {rel}")
            continue

        extra = set(data.keys()) - ALLOWED_TOP_LEVEL
        if extra:
            errors.append(
                f"BASE UNKNOWN TOP-LEVEL KEYS [{rel}]: {sorted(extra)} "
                f"(allowed: {sorted(ALLOWED_TOP_LEVEL)})"
            )

        # views must be a list of objects with a type from ALLOWED_VIEW_TYPES
        views = data.get("views", [])
        if not isinstance(views, list):
            errors.append(f"BASE 'views' must be a list in {rel}")
        else:
            for i, v in enumerate(views):
                if not isinstance(v, dict):
                    errors.append(f"BASE view[{i}] in {rel} is not a mapping")
                    continue
                vtype = v.get("type")
                if vtype not in ALLOWED_VIEW_TYPES:
                    errors.append(
                        f"BASE view[{i}] in {rel} has invalid type {vtype!r} "
                        f"(allowed: {sorted(ALLOWED_VIEW_TYPES)})"
                    )
                if "name" not in v:
                    warnings.append(f"BASE view[{i}] in {rel} has no 'name'")

        # formulas must be string expressions
        formulas = data.get("formulas", {})
        if not isinstance(formulas, dict):
            errors.append(f"BASE 'formulas' must be a mapping in {rel}")
        else:
            for fname, fexpr in formulas.items():
                if not isinstance(fexpr, str):
                    errors.append(f"BASE formula {fname!r} must be a string in {rel}")

        # Heuristic: look for frontmatter field references in filters/formulas text
        # Extract bareword identifiers that look like frontmatter fields
        if known_fields:
            import re as _re
            ident_re = _re.compile(r"(?<![.a-zA-Z_])([a-z][a-z0-9_]{2,})(?![a-zA-Z_(])")
            referenced = set(ident_re.findall(text))
            # Filter to words that plausibly look like fields (exclude keywords, etc.)
            keywords = {"if", "else", "and", "or", "not", "true", "false", "contains",
                        "inFolder", "null", "in", "is", "as"}
            suspicious = referenced - known_fields - bases_reserved - keywords
            # Only warn if the token appears to be used in a filter/formula context
            # (we can't be too strict without a real parser)
            for field in sorted(suspicious):
                # Skip if it shows up inside a string literal
                # Simple heuristic: check it's used in a `field == value` or `field.` pattern
                if _re.search(rf'{_re.escape(field)}\s*[=!<>]', text) or \
                   _re.search(rf'{_re.escape(field)}\s*\.', text):
                    warnings.append(
                        f"BASE [{rel}]: references '{field}' which isn't a known "
                        f"frontmatter field (could be a typo)"
                    )

        print(f"  ✓ base: {rel}")


def check_manifest():
    path = VAULT / "raw" / ".manifest.json"
    schema = load_schema("manifest.schema.json")
    if schema:
        validate_json_file(path, schema, "manifest")


def check_settings():
    for rel in (".claude/settings.json", ".claude/settings.local.json"):
        p = VAULT / rel
        if not p.exists():
            continue
        schema = load_schema("settings.schema.json")
        if schema:
            validate_json_file(p, schema, "settings")


def check_all_wiki_frontmatter():
    schema_doc = load_schema("frontmatter.schema.json")
    if not schema_doc:
        return
    for folder, key in [
        ("Sources", "Source"),
        ("Concepts", "Concept"),
        ("Entities", "Entity"),
        ("Questions", "Question"),
        ("Outputs", "Output"),
    ]:
        validate_wiki_pages(folder, schema_doc["definitions"][key], required=True)

    # Concept pages: check for mandatory sections
    concepts = VAULT / "Concepts"
    if concepts.is_dir():
        for page in concepts.glob("*.md"):
            validate_concept_sections(page)


def main():
    print(f"Validating vault: {VAULT}")
    print()

    print("--- Required files ---")
    check_required_files()
    print()

    print("--- Symlink ---")
    check_symlink()
    print()

    print("--- appearance.json snippet ---")
    check_appearance_enables_snippet()
    print()

    print("--- Script executability ---")
    check_scripts_executable()
    print()

    print("--- Bash 3.2 compatibility ---")
    check_bash_portability()
    print()

    print("--- Base files ---")
    check_base_files()
    print()

    print("--- Manifest schema ---")
    check_manifest()
    print()

    print("--- Settings schema ---")
    check_settings()
    print()

    print("--- Templates ---")
    check_templates()
    print()

    print("--- Wiki page frontmatter ---")
    check_all_wiki_frontmatter()
    print()

    print("=" * 60)
    if warnings:
        print(f"\n{len(warnings)} WARNING(S):")
        for w in warnings:
            print(f"  ⚠ {w}")

    if errors:
        print(f"\n{len(errors)} ERROR(S):")
        for e in errors:
            print(f"  ✗ {e}")
        sys.exit(1)

    print("\n✓ All validation checks passed")
    sys.exit(0)


if __name__ == "__main__":
    main()
