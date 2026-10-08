#!/usr/bin/env python3
"""Validate the explicit Refactoring v2 move plan while owners migrate coherently."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re

from validate_domain_structure import APPROVED_DOMAINS, CANONICAL_ROLE_DIRS, ROLE_SCRIPT_RULES

ROOT = Path(__file__).resolve().parents[1]
MAP_PATH = Path("utils/domain_migration_map.json")
CLASS_NAME = re.compile(r"^class_name\s+(\w+)", re.MULTILINE)


def validate_migration_map(root: Path = ROOT, map_path: Path | None = None) -> list[str]:
    """Check coverage, single targets, owner roles and UID pairing; accept completed source-to-target moves."""
    errors: list[str] = []
    plan_path = map_path if map_path is not None else root / MAP_PATH
    try:
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        return [f"{plan_path}: cannot read migration plan: {error}"]
    if not isinstance(plan, dict) or plan.get("version") != 1:
        return [f"{plan_path}: expected version-1 migration object."]
    if set(plan.get("owners", [])) != APPROVED_DOMAINS:
        errors.append("Migration owner list must match the approved gameplay domains.")
    rows = plan.get("files", [])
    if not isinstance(rows, list):
        return ["Migration files must be an explicit list."]
    sources: dict[str, dict] = {}
    targets: dict[str, str] = {}
    for row in rows:
        if not isinstance(row, dict):
            errors.append("Migration entry must be an object.")
            continue
        source, target = row.get("source", ""), row.get("target", "")
        if not all(isinstance(path, str) and path.startswith("content/") and ".." not in Path(path).parts and "\\" not in path for path in [source, target]):
            errors.append(f"Invalid repository content paths: {source!r} -> {target!r}.")
            continue
        if source in sources:
            errors.append(f"Duplicate migration source: {source}.")
        if target in targets:
            errors.append(f"Duplicate migration target: {target} ({targets[target]}, {source}).")
        sources[source] = row
        targets[target] = source
        owner, role = row.get("owner"), row.get("role")
        if owner == "global":
            if source != target and not target.startswith(("content/ui/", "content/scenes/")):
                errors.append(f"{source}: moved global glue must target content/ui/ or content/scenes/.")
        elif owner not in APPROVED_DOMAINS and owner != "shared":
            errors.append(f"{source}: unknown owner {owner!r}.")
        else:
            prefix = f"content/domains/{owner}/{role}/" if owner != "shared" else f"content/shared/{role}/"
            if role not in CANONICAL_ROLE_DIRS or not target.startswith(prefix):
                errors.append(f"{source}: target does not match canonical owner/role {owner}/{role}.")
        if row.get("task") not in {"29", "30", "31", "32", "retain"}:
            errors.append(f"{source}: missing owning migration task.")
        source_path, target_path = root / source, root / target
        if source != target and source_path.exists() and target_path.exists():
            errors.append(f"{source}: both old and new files exist; no permanent parallel migration path.")
        active_path = source_path if source_path.is_file() else target_path
        if not active_path.is_file():
            errors.append(f"{source}: neither source nor target exists.")
        elif row.get("uid"):
            text = active_path.read_text(encoding="utf-8")
            declared_uid = text.strip() if active_path.suffix == ".uid" else None
            if declared_uid is None:
                header = text.splitlines()[0] if text else ""
                match = re.search(r'\buid="([^"]+)"', header)
                declared_uid = match.group(1) if match else ""
            if declared_uid != row["uid"]:
                errors.append(f"{source}: original authored UID changed during migration.")
        if active_path.is_file() and target.endswith(".gd"):
            declared = CLASS_NAME.search(active_path.read_text(encoding="utf-8"))
            if row.get("symbol") and (declared is None or declared.group(1) != row["symbol"]):
                errors.append(f"{source}: public symbol no longer matches the explicit map.")
            rule = ROLE_SCRIPT_RULES.get(role) if owner != "global" else None
            if rule and (not Path(target).name.startswith(rule[0]) or (declared and not declared.group(1).startswith(rule[1]))):
                errors.append(f"{source}: target script violates canonical {role} prefix.")
    for source, row in sources.items():
        if source.endswith(".uid"):
            base = sources.get(source.removesuffix(".uid"))
            if base is None or row["target"] != base["target"] + ".uid" or any(row.get(key) != base.get(key) for key in ["owner", "role", "task"]):
                errors.append(f"{source}: UID must follow its source asset with the same owner/task.")
        elif (root / (source + ".uid")).is_file() and source + ".uid" not in sources:
            errors.append(f"{source}: source UID is missing from the migration map.")
    for legacy_root in plan.get("roots", []):
        for path in (root / "content" / legacy_root).rglob("*"):
            if path.is_file() and not path.name.endswith(".import") and path.relative_to(root).as_posix() not in sources:
                errors.append(f"{path.relative_to(root).as_posix()}: legacy gameplay file missing from the migration map.")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    errors = validate_migration_map(args.root.resolve())
    if errors:
        print("Domain migration map validation: FAIL")
        for error in errors:
            print("- " + error)
        return 1
    print("Domain migration map validation: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
