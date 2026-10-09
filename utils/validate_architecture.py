#!/usr/bin/env python3
"""Detect lexical hidden-System patterns without parsing gameplay semantics.

All project-owned GDScript is discovered independently of role layout. The
temporary baseline budgets occurrences by class/method/target, so moving a file
cannot erase debt and adding another occurrence cannot hide behind old debt.
Indirect scheduling, aliases and authority require architecture review.
"""

from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "utils/architecture_baseline.json"
EXCLUDED = {"addons", "tests", "node_modules", "__pycache__"}
STEP = r"(?:tick|update|process)"
FUNCTION = re.compile(r"^(?P<static>static\s+)?func\s+(?P<name>\w+)\s*\(")
SERVICE_CALL = re.compile(rf"\b(\w+Service)\s*\.\s*({STEP})\b")


@dataclass(frozen=True)
class Finding:
    rule: str
    owner: str
    method: str
    target: str
    path: str
    line: int

    @property
    def key(self) -> tuple[str, str, str, str]:
        return self.rule, self.owner, self.method, self.target


def code_only(source: str) -> str:
    """Blank comments and quoted text, preserving offsets and newlines.

    This is a small lexical filter, not a GDScript syntax/indentation parser.
    It handles escaped quotes and triple-quoted text so examples cannot trigger
    execution rules. Godot remains the parser authority.
    """
    output = list(source)
    index = 0
    while index < len(source):
        if source[index] == "#":
            end = source.find("\n", index)
            end = len(source) if end < 0 else end
        elif source[index] in "\"'":
            quote = source[index]
            delimiter = quote * 3 if source.startswith(quote * 3, index) else quote
            end = index + len(delimiter)
            while end < len(source):
                if source[end] == "\\":
                    end += 2
                elif source.startswith(delimiter, end):
                    end += len(delimiter)
                    break
                else:
                    end += 1
        else:
            index += 1
            continue
        for offset in range(index, min(end, len(source))):
            if source[offset] != "\n":
                output[offset] = " "
        index = end
    return "".join(output)


def discover(root: Path) -> list[Path]:
    paths: list[Path] = []
    for directory, children, files in os.walk(root):
        children[:] = sorted(
            name for name in children if name not in EXCLUDED and not name.startswith(".")
        )
        if ".gdignore" in files:
            children[:] = []
            continue
        paths.extend(Path(directory) / name for name in sorted(files) if name.endswith(".gd"))
    return paths


def deferred_owner_findings(scripts: dict[str, tuple[str, str]]) -> list[Finding]:
    """Reject bound typed Nodes before their callback can perform lifetime checks.

    This deliberately checks direct custom-buffer bindings only. Resource payload
    references still require runtime validation; native synchronous signals have
    no pending buffer capture. Godot parser/runtime tests remain authoritative.
    """
    parents: dict[str, str] = {}
    signatures: dict[tuple[str, str], str] = {}
    for owner, (_, source) in scripts.items():
        base = re.search(r"^extends\s+(\w+)", source, re.MULTILINE)
        if base:
            parents[owner] = base.group(1)
        for function in re.finditer(r"^(?:static\s+)?func\s+(\w+)\s*\((.*?)\)", source, re.MULTILINE | re.DOTALL):
            signatures[(owner, function.group(1))] = function.group(2)

    node_bases = {"Entity", "Node", "Node2D", "Node3D", "Control", "World",
                  "PhysicsBody3D", "RigidBody3D", "CharacterBody3D", "Area3D"}

    def is_node(type_name: str) -> bool:
        visited: set[str] = set()
        while type_name not in visited:
            if type_name in node_bases:
                return True
            visited.add(type_name)
            type_name = parents.get(type_name, "")
        return False

    findings: list[Finding] = []
    queued = re.compile(r"\bcmd\s*\.\s*add_custom\s*\(\s*([\w.]+)\s*\.\s*bind\s*\(")
    structural = re.compile(r"\bcmd\s*\.\s*(add_component|remove_component|add_components|remove_components|add_entity|remove_entity|add_relationship|remove_relationship)\s*\(")
    for owner, (relative, source) in scripts.items():
        if not ({"systems", "observers"} & set(Path(relative).parts)
                or parents.get(owner) in {"System", "Observer"}):
            continue
        for capture in queued.finditer(source):
            target = capture.group(1)
            parts = target.split(".")
            callback_owner, method = (owner, parts[0]) if len(parts) == 1 else (parts[0], parts[-1])
            signature = signatures.get((callback_owner, method), "")
            bound_nodes = [type_name for type_name in re.findall(r":\s*(\w+)", signature) if is_node(type_name)]
            if bound_nodes or (len(parts) > 1 and method == "remove_relationship"):
                findings.append(Finding("queued-typed-node", owner, "<buffer>", target,
                                        relative, source.count("\n", 0, capture.start()) + 1))
        # Pinned GECS structural closures log an engine capture error even before
        # their internal is_instance_valid guard. Keep safe WeakRef callbacks in
        # the project owner instead of introducing an addon compatibility layer.
        for capture in structural.finditer(source):
            findings.append(Finding("queued-node-closure", owner, "<buffer>", capture.group(1),
                                    relative, source.count("\n", 0, capture.start()) + 1))
    return findings


def scan(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    scripts: dict[str, tuple[str, str]] = {}
    for path in discover(root):
        relative = path.relative_to(root).as_posix()
        source = code_only(path.read_text(encoding="utf-8-sig"))
        class_match = re.search(r"^class_name\s+(\w+)", source, re.MULTILINE)
        owner = class_match.group(1) if class_match else relative
        scripts[owner] = (relative, source)
        role_parts = path.relative_to(root).parts
        is_service = owner.endswith("Service") or "services" in role_parts
        is_system = (
            "systems" in role_parts or owner.startswith("S_")
            or bool(re.search(r"^extends\s+System\b", source, re.MULTILINE))
        )
        method = "<script>"
        static_step = False
        for number, line in enumerate(source.splitlines(), start=1):
            declaration = FUNCTION.match(line)
            if declaration:
                method = declaration.group("name")
                static_step = bool(
                    is_service and declaration.group("static") and re.fullmatch(STEP, method)
                )
                if static_step:
                    findings.append(Finding("service-step", owner, method, "", relative, number))
            elif line.strip() and not line[0].isspace():
                method = "<script>"
                static_step = False

            if is_system:
                for call in SERVICE_CALL.finditer(line):
                    target = f"{call.group(1)}.{call.group(2)}"
                    findings.append(Finding("system-service-step", owner, method, target, relative, number))
            if is_system:
                for call in re.finditer(r"\b(S_\w+)\s*\.\s*(\w+)\s*\(", line):
                    if call.group(2) != "new":
                        findings.append(Finding("system-calls-system", owner, method,
                                                f"{call.group(1)}.{call.group(2)}", relative, number))
            if static_step and re.search(r"\bECS\s*\.\s*world\s*\.\s*query\b", line):
                findings.append(Finding("service-step-query", owner, method, "", relative, number))
    findings.extend(deferred_owner_findings(scripts))
    return findings


def validate(findings: list[Finding], baseline: dict, strict: bool = False) -> list[str]:
    errors: list[str] = []
    budgets: dict[tuple[str, str, str, str], int] = {}
    rules = {"service-step", "system-service-step", "service-step-query"}
    for entry in baseline.get("entries", []):
        key = tuple(entry.get(name, "") for name in ("rule", "owner", "method", "target"))
        if key in budgets:
            errors.append(f"duplicate baseline entry: {key}")
        if (
            key[0] not in rules or not key[1] or not key[2]
            or type(entry.get("count")) is not int or entry["count"] < 1
            or not entry.get("reason", "").strip()
            or not entry.get("task", "").strip()
            or entry.get("removal_gate") != "26/27"
        ):
            errors.append(f"invalid baseline entry: {key}")
            continue
        budgets[key] = entry["count"]

    counts = Counter(finding.key for finding in findings)
    for key, count in counts.items():
        allowed = 0 if strict else budgets.get(key, 0)
        if count > allowed:
            location = next(f for f in findings if f.key == key)
            errors.append(
                f"{location.path}:{location.line}: {key[0]} {key[1]}.{key[2]}"
                f" {key[3]} ({count} occurrences; allowed {allowed})"
            )
    # Removing debt also removes its permission. Never leave stale allowances.
    for key, count in budgets.items():
        if counts.get(key, 0) < count:
            errors.append(f"stale baseline budget: {key}; trim/remove with the owning migration")
    if strict and budgets:
        errors.append("strict execution gate requires an empty migration baseline (task 26/27)")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--baseline", type=Path, default=BASELINE)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--inventory", action="store_true", help="Print findings; do not generate allowances")
    args = parser.parse_args()
    findings = scan(args.root.resolve())
    if args.inventory:
        print(json.dumps([finding.__dict__ for finding in findings], indent=2))
        return 0
    try:
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
        if baseline.get("version") != 1 or not isinstance(baseline.get("entries"), list):
            raise ValueError("expected version 1 and an entries list")
        errors = validate(findings, baseline, args.strict)
    except (OSError, ValueError, TypeError, AttributeError) as error:
        errors = [f"invalid/missing architecture baseline: {error}"]
    print(f"Architecture validation: {'FAIL' if errors else 'PASS'} ({len(findings)} lexical findings)")
    for error in errors:
        print(f"- {error}")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
