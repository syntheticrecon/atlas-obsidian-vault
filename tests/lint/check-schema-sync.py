#!/usr/bin/env python3
"""
Enforce consistency between three sources of truth for frontmatter fields:

1. AGENTS.md — the "Recommended Frontmatter Schema" markdown table (prose)
2. tests/schemas/frontmatter.schema.json — JSON Schema (code)
3. _templates/*.md — template scaffolds (scaffold)

Fails on drift. The fix is to update whichever is wrong.

Usage:
    python3 tests/lint/check-schema-sync.py [vault-path]

Exit codes:
    0 — in sync
    1 — drift detected
    2 — dependency missing or parse error
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(2)


VAULT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
TESTS_DIR = VAULT / "tests"
AGENTS_MD = VAULT / "AGENTS.md"
SCHEMA_JSON = TESTS_DIR / "schemas" / "frontmatter.schema.json"
TEMPLATES_DIR = VAULT / "_templates"

PAGE_TYPES = ["Source", "Concept", "Entity", "Question", "Output"]
TEMPLATE_FILE = {
    "Source": "Source.md",
    "Concept": "Concept.md",
    "Entity": "Entity.md",
    "Question": "Question.md",
    "Output": "Output.md",
}
AGENTS_ROW_KEY = {
    "Source": "Sources/",
    "Concept": "Concepts/",
    "Entity": "Entities/",
    "Question": "Questions/",
    "Output": "Outputs/",
}

# Extract `field_name` or `field_name: value` from a table cell
FIELD_RE = re.compile(r"`([a-z_][a-z0-9_]*)(?::\s*[^`]+)?`")
# Extract enums from `type (article / paper / thread / book / video)`
ENUM_RE = re.compile(r"`([a-z_]+)`\s*\(([a-z\s/]+)\)")

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


errors: list[str] = []


def parse_agents_table() -> dict[str, dict]:
    """Return {page_type: {"fields": [names], "enums": {field: [values]}}}"""
    if not AGENTS_MD.exists():
        errors.append(f"AGENTS.md not found at {AGENTS_MD}")
        return {}
    try:
        text = AGENTS_MD.read_text()
    except Exception as e:
        errors.append(f"Failed to read AGENTS.md: {e}")
        return {}

    # Find the Recommended Frontmatter Schema section
    m = re.search(
        r"##\s+Recommended Frontmatter Schema\s*\n(.*?)(?:\n##\s|\Z)",
        text,
        re.DOTALL,
    )
    if not m:
        errors.append("AGENTS.md: could not find '## Recommended Frontmatter Schema' section")
        return {}

    section = m.group(1)
    result: dict[str, dict] = {pt: {"fields": [], "enums": {}} for pt in PAGE_TYPES}

    for pt, row_key in AGENTS_ROW_KEY.items():
        # Find the row for this page type
        # Row looks like: | Sources/ | `field1`, `field2` (option / option), `field3` |
        row_re = re.compile(
            rf"\|\s*{re.escape(row_key)}\s*\|\s*(.*?)\s*\|",
            re.DOTALL,
        )
        row_match = row_re.search(section)
        if not row_match:
            errors.append(f"AGENTS.md table missing row for {row_key}")
            continue
        cell = row_match.group(1)
        fields = FIELD_RE.findall(cell)
        result[pt]["fields"] = list(dict.fromkeys(fields))  # dedupe, preserve order

        # Extract enums
        for enum_match in ENUM_RE.finditer(cell):
            field = enum_match.group(1)
            values_raw = enum_match.group(2)
            values = [v.strip() for v in values_raw.split("/") if v.strip()]
            result[pt]["enums"][field] = values

    return result


def load_schema() -> dict:
    if not SCHEMA_JSON.exists():
        errors.append(f"Schema not found at {SCHEMA_JSON}")
        return {}
    try:
        return json.loads(SCHEMA_JSON.read_text())
    except Exception as e:
        errors.append(f"Failed to parse schema: {e}")
        return {}


def load_template(page_type: str) -> dict | None:
    path = TEMPLATES_DIR / TEMPLATE_FILE[page_type]
    if not path.exists():
        errors.append(f"Template missing: {path.relative_to(VAULT)}")
        return None
    try:
        content = path.read_text()
    except Exception as e:
        errors.append(f"Failed to read {path.relative_to(VAULT)}: {e}")
        return None
    m = FRONTMATTER_RE.match(content)
    if not m:
        errors.append(f"Template has no frontmatter: {path.relative_to(VAULT)}")
        return None
    try:
        data = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError as e:
        errors.append(f"Invalid YAML in {path.relative_to(VAULT)}: {e}")
        return None
    return data if isinstance(data, dict) else {}


def check_page_type(page_type: str, agents: dict, schema_doc: dict) -> None:
    print(f"\n--- {page_type} ---")
    agents_fields = set(agents.get(page_type, {}).get("fields", []))
    agents_enums = agents.get(page_type, {}).get("enums", {})

    definitions = schema_doc.get("definitions", {})
    page_schema = definitions.get(page_type, {})
    schema_props = set(page_schema.get("properties", {}).keys())
    schema_required = set(page_schema.get("required", []))

    template = load_template(page_type) or {}
    template_fields = set(template.keys())

    # Rule 1: every field in AGENTS.md table must be in the schema (as properties)
    for f in agents_fields:
        if f not in schema_props:
            errors.append(
                f"[{page_type}] field '{f}' in AGENTS.md table but not in schema properties"
            )

    # Rule 2: every required field in schema must be in AGENTS.md table
    for f in schema_required:
        if f not in agents_fields:
            errors.append(
                f"[{page_type}] schema requires '{f}' but AGENTS.md table doesn't list it"
            )

    # Rule 3: every required field must be in the template
    for f in schema_required:
        if f not in template_fields:
            errors.append(
                f"[{page_type}] template missing required field '{f}'"
            )

    # Rule 4: every template field must be in the schema (no unknown fields)
    for f in template_fields:
        if f not in schema_props:
            errors.append(
                f"[{page_type}] template has field '{f}' not defined in schema"
            )

    # Rule 5: enum values in AGENTS.md must match schema enums
    for field, agents_values in agents_enums.items():
        if field not in schema_props:
            continue
        schema_field = page_schema["properties"][field]
        schema_values = schema_field.get("enum")
        if schema_values is None:
            # Schema doesn't constrain, OK
            continue
        agents_set = set(agents_values)
        schema_set = set(v for v in schema_values if v)  # drop empty-string "allow blank"
        # AGENTS.md must not list values that aren't in schema
        extra = agents_set - schema_set
        if extra:
            errors.append(
                f"[{page_type}] AGENTS.md lists enum values for '{field}' not in schema: "
                f"{sorted(extra)} (schema: {sorted(schema_set)})"
            )

    print(f"  AGENTS.md fields:  {sorted(agents_fields) or '(none)'}")
    print(f"  Schema properties: {sorted(schema_props) or '(none)'}")
    print(f"  Template fields:   {sorted(template_fields) or '(none)'}")


def main() -> int:
    print(f"Checking schema/AGENTS.md/template sync under {VAULT}")

    agents = parse_agents_table()
    schema_doc = load_schema()
    if not agents or not schema_doc:
        # Fatal parse errors already recorded
        pass

    for pt in PAGE_TYPES:
        check_page_type(pt, agents, schema_doc)

    print("\n" + "=" * 60)
    if errors:
        print(f"\n{len(errors)} DRIFT(S) DETECTED:")
        for e in errors:
            print(f"  ✗ {e}")
        return 1

    print("\n✓ AGENTS.md, schema, and templates are in sync")
    return 0


if __name__ == "__main__":
    sys.exit(main())
