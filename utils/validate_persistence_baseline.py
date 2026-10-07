#!/usr/bin/env python3
"""Check the Phase 1 save-visible script/field inventory against the closed codec.

This deliberately reads only the codec's explicit flat lists and class names.
It is not a GDScript parser. A changed declaration shape needs an explicit
inventory-tool update, not an inferred migration or a save alias.
"""

from __future__ import annotations

import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tests/fixtures/refactoring_v2/save_visible_paths.json"


def inventory(root: Path) -> dict:
    codec = (root / "content/services/persistence/save_data_codec.gd").read_text(encoding="utf-8")
    fields = {
        name: re.findall(r'"([^"]+)"', declaration)
        for name, declaration in re.findall(r"^\s*(C_\w+): \[([^\n]*)\],?$", codec, re.MULTILINE)
    }
    records = re.search(r"^static var _record_types[^=]*= \[([^\n]+)\]$", codec, re.MULTILINE)
    if not fields or not records:
        raise ValueError("closed codec declarations changed shape; update inventory explicitly")
    record_names = [name.strip() for name in records.group(1).split(",")]
    classes = {}
    for path in (root / "content").rglob("*.gd"):
        match = re.search(r"^class_name\s+(\w+)", path.read_text(encoding="utf-8"), re.MULTILINE)
        if match:
            classes[match.group(1)] = "res://" + path.relative_to(root).as_posix()
    return {
        "components": [dict(symbol=name, path=classes[name], fields=allowed) for name, allowed in fields.items()],
        "records": [dict(symbol=name, path=classes[name]) for name in record_names],
    }


def validate(root: Path = ROOT) -> list[str]:
    errors = []
    manifest = json.loads((root / "tests/fixtures/refactoring_v2/save_visible_paths.json").read_text(encoding="utf-8"))
    actual = inventory(root)
    for category in ("components", "records"):
        if manifest.get(category) != actual[category]:
            errors.append(f"save-visible {category} changed; update schema decision and baseline explicitly")
    store = (root / "content/services/persistence/autosave_store.gd").read_text(encoding="utf-8")
    version = re.search(r"const SCHEMA_VERSION: int = (\d+)", store)
    if version is None or manifest.get("schema") != int(version.group(1)):
        errors.append("supported schema differs from baseline")
    fixture = root / "tests/fixtures/refactoring_v2/schema2_snapshot.variant"
    if not fixture.is_file():
        errors.append("isolated current-format snapshot fixture is missing")
    else:
        paths = sorted(set(re.findall(r"res://[^\s\"']+", fixture.read_text(encoding="utf-8"))))
        if paths != manifest.get("snapshot_paths"):
            errors.append("snapshot serialized paths differ from the inspected migration inventory")
        for path in paths:
            # Inline Definitions retain a Godot subresource identity after ::.
            # The engine fixture validates that subresource; static IO checks its file.
            file_path = path.removeprefix("res://").split("::", 1)[0]
            if not (root / file_path).is_file():
                errors.append(f"snapshot path is unresolved: {path}")
    return errors


if __name__ == "__main__":
    try:
        errors = validate()
    except (OSError, ValueError, KeyError) as error:
        errors = [str(error)]
    print("Persistence baseline validation: " + ("FAIL" if errors else "PASS"))
    for error in errors:
        print("- " + error)
    raise SystemExit(bool(errors))
