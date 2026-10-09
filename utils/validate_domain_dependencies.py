#!/usr/bin/env python3
"""Validate explicit domain access and acyclic implementation, with exact expiring legacy edges."""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field
import json
from pathlib import Path
import re

from validate_architecture import code_only
from validate_domain_structure import APPROVED_DOMAINS, get_content_role

ROOT = Path(__file__).resolve().parents[1]
DATA_ROLES = {"components", "relationships", "contracts", "definitions"}
RIGHTS = {"read", "query", "request", "subscribe", "restore", "configure"}
CLASS_NAME = re.compile(r"^class_name\s+(\w+)", re.MULTILINE)
METHOD = re.compile(r"^(?:static\s+)?func\s+(\w+)\s*\(", re.MULTILINE)


@dataclass
class ScriptInfo:
    path: str
    stable_path: str
    owner: str
    role: str
    symbol: str
    text: str
    code: str
    methods: set[str] = field(default_factory=set)
    imports: set[str] = field(default_factory=set)
    aliases: dict[str, str] = field(default_factory=dict)
    parent: str = ""


@dataclass(frozen=True)
class Finding:
    rule: str
    source: str
    source_owner: str
    target_symbol: str
    target_owner: str
    target_path: str
    reason: str

    @property
    def key(self) -> tuple[str, str, str]:
        return self.rule, self.source, self.target_symbol


def _json(path: Path, default: dict) -> dict:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def _literals(source: str) -> list[tuple[int, str]]:
    """Read actual quoted literals, excluding comments and nested text inside another string."""
    literals: list[tuple[int, str]] = []
    cursor = 0
    while cursor < len(source):
        if source[cursor] == "#":
            end = source.find("\n", cursor)
            cursor = len(source) if end < 0 else end
        elif source[cursor] in "\"'":
            start = cursor
            quote = source[cursor]
            delimiter = quote * 3 if source.startswith(quote * 3, cursor) else quote
            cursor += len(delimiter)
            content = cursor
            while cursor < len(source):
                if source[cursor] == "\\":
                    cursor += 2
                elif source.startswith(delimiter, cursor):
                    literals.append((start, source[content:cursor]))
                    cursor += len(delimiter)
                    break
                else:
                    cursor += 1
        else:
            cursor += 1
    return literals


def imported_paths(text: str, code: str) -> tuple[set[str], dict[str, str]]:
    """Recognize load/preload/extends and named constant loads; plain diagnostic strings are not imports."""
    imports: set[str] = set()
    constants: dict[str, str] = {}
    aliases: dict[str, str] = {}
    for position, value in _literals(text):
        if not value.startswith("res://"):
            continue
        path = value.removeprefix("res://")
        prefix = code[:position]
        direct = re.search(r"\b(?:load|preload)\s*\(\s*$", prefix)
        extends = re.search(r"(?:^|\n)\s*extends\s*$", prefix)
        constant = re.search(r"\bconst\s+(\w+)(?:\s*:\s*\w+)?\s*=\s*$", prefix)
        if direct or extends:
            imports.add(path)
            assignment = re.search(r"\b(?:const|var)\s+(\w+)(?:\s*:\s*\w+)?\s*=\s*(?:load|preload)\s*\(\s*$", prefix)
            if assignment:
                aliases[assignment.group(1)] = path
        if constant:
            constants[constant.group(1)] = path
    for name, path in constants.items():
        if re.search(r"\b(?:load|preload)\s*\(\s*" + re.escape(name) + r"\s*\)", code):
            imports.add(path)
    return imports, aliases


def script_index(root: Path, plan: dict) -> tuple[dict[str, ScriptInfo], dict[str, ScriptInfo]]:
    rows = plan.get("files", [])
    by_path = {row[key]: row for row in rows for key in ["source", "target"]}
    scripts: dict[str, ScriptInfo] = {}
    symbols: dict[str, ScriptInfo] = {}
    for path in sorted((root / "content").rglob("*.gd")):
        relative = path.relative_to(root).as_posix()
        row = by_path.get(relative)
        parts = path.relative_to(root / "content").parts
        owner = row["owner"] if row else parts[1] if parts[0] == "domains" else "shared" if parts[0] == "shared" else "global"
        role = row["role"] if row else get_content_role(root, path) or parts[0]
        text = path.read_text(encoding="utf-8")
        code = code_only(text)
        match = CLASS_NAME.search(code)
        symbol = match.group(1) if match else "@" + (row["source"] if row else relative)
        imports, aliases = imported_paths(text, code)
        info = ScriptInfo(relative, row["source"] if row else relative, owner, role, symbol, text, code, set(METHOD.findall(code)), imports, aliases)
        parent = re.search(r"^extends\s+(\w+)", code, re.MULTILINE)
        info.parent = parent.group(1) if parent else ""
        scripts[relative] = info
        if symbol in symbols:
            raise ValueError(f"Duplicate project class symbol {symbol}: {symbols[symbol].path}, {relative}")
        symbols[symbol] = info
    return scripts, symbols


def _forbidden(source: ScriptInfo, target: ScriptInfo) -> str:
    if source.owner == target.owner:
        return ""
    if source.owner == "shared" and target.owner != "shared":
        return "shared imports no domain/global gameplay implementation"
    if source.owner != "global" and target.owner == "persistence":
        return "domains cannot import persistence"
    if source.owner not in {"global", "shared"} and target.owner == "global" and target.path.split("/")[1] in {"ui", "scenes", "dialogue", "presentation"}:
        return "domains cannot import global UI/composition"
    if source.owner == "npc" and target.owner == "customers" and target.role not in {"contracts", "definitions"}:
        return "base NPC imports Customer behavior/state"
    return ""


def _method_owner(target: ScriptInfo, method: str, symbols: dict[str, ScriptInfo], visited: set[str] | None = None) -> ScriptInfo | None:
    visited = set() if visited is None else visited
    if target.path in visited:
        return None
    visited.add(target.path)
    if method in target.methods:
        return target
    parent = symbols.get(target.parent)
    return _method_owner(parent, method, symbols, visited) if parent else None


def implementation_targets(source: ScriptInfo, scripts: dict[str, ScriptInfo], symbols: dict[str, ScriptInfo]) -> set[str]:
    """Separate metadata/type/leaf references from actual calls, inheritance and behavioral script imports."""
    targets: set[str] = set()
    if source.parent in symbols:
        targets.add(symbols[source.parent].path)
    for path in source.imports:
        target = scripts.get(path)
        if target and target.role not in DATA_ROLES:
            targets.add(path)
    for name, method in re.findall(r"\b(\w+)\s*\.\s*(\w+)\s*\(", source.code):
        target = symbols.get(name) or scripts.get(source.aliases.get(name, ""))
        if target:
            if method == "new":
                if target.role not in DATA_ROLES:
                    targets.add(target.path)
            else:
                declared = _method_owner(target, method, symbols)
                if declared:
                    targets.add(declared.path)
    # Project-owned GDScript is typed: direct variable/parameter API calls can be
    # resolved without treating every actor/record annotation as an implementation import.
    typed: dict[str, set[str]] = {}
    for name, typename in re.findall(r"\b(\w+)\s*:\s*(\w+)", source.code):
        if typename in symbols:
            typed.setdefault(name, set()).add(typename)
    for name, method in re.findall(r"\b(\w+)\s*\.\s*(\w+)\s*\(", source.code):
        for typename in typed.get(name, set()):
            declared = _method_owner(symbols[typename], method, symbols)
            if declared:
                targets.add(declared.path)
    targets.discard(source.path)
    return targets


def _cycle(graph: dict[str, set[str]]) -> list[tuple[str, str]]:
    """Return one actual directed cycle, rather than rejecting reciprocal coarse data edges."""
    state: dict[str, int] = {}
    stack: list[str] = []
    def visit(node: str) -> list[tuple[str, str]]:
        state[node] = 1
        stack.append(node)
        for target in sorted(graph.get(node, set())):
            if state.get(target) == 1:
                cycle = stack[stack.index(target):] + [target]
                return list(zip(cycle, cycle[1:]))
            if state.get(target, 0) == 0:
                found = visit(target)
                if found:
                    return found
        stack.pop()
        state[node] = 2
        return []
    for node in sorted(graph):
        if state.get(node, 0) == 0:
            found = visit(node)
            if found:
                return found
    return []


def _edge_in_cycle(graph: dict[str, set[str]], source: str, target: str) -> bool:
    if target not in graph.get(source, set()):
        return False
    pending = [target]
    visited: set[str] = set()
    while pending:
        node = pending.pop()
        if node == source:
            return True
        if node not in visited:
            visited.add(node)
            pending.extend(graph.get(node, set()))
    return False


def _task_for(info: ScriptInfo, plan: dict) -> str:
    row = next((row for row in plan.get("files", []) if row["source"] == info.stable_path), None)
    if row and row["task"] != "retain":
        return row["task"]
    return "29" if info.owner in {"npc", "customers"} else "30" if info.owner in {"interaction", "combat", "motion"} else "32" if info.owner == "shared" else "31"


def analyze(root: Path, manifest: dict, plan: dict) -> tuple[list[Finding], dict[str, set[str]], dict[str, ScriptInfo], list[str]]:
    scripts, symbols = script_index(root, plan)
    errors: list[str] = []
    public: dict[tuple[str, str, str], dict] = {}
    future = {row["target"]: row["source"] for row in plan.get("files", [])}
    for edge in manifest.get("public_edges", []):
        key = (edge.get("source_owner", ""), edge.get("target_owner", ""), edge.get("symbol", ""))
        if key in public:
            errors.append(f"Duplicate public edge: {key}.")
        public[key] = edge
        target = symbols.get(key[2])
        if target is None and key[2].startswith("@"):
            target = next((info for info in scripts.values() if info.stable_path == key[2][1:]), None)
        if target is None or target.owner != key[1] or target.stable_path != future.get(edge.get("path", ""), edge.get("path", "")):
            errors.append(f"Unknown/mismatched public target: {key[2]} at {edge.get('path')}.")
        if not set(edge.get("rights", [])) or not set(edge.get("rights", [])) <= RIGHTS:
            errors.append(f"Invalid/missing access rights: {key}.")
        operations = set(edge.get("public_methods", [])) | set(edge.get("public_instance_methods", []))
        for operation in operations:
            if operation.startswith("_") or (target and operation != "new" and _method_owner(target, operation, symbols) is None):
                errors.append(f"Invalid/private public operation {operation!r} in {key}.")
        for operation, right in edge.get("method_rights", {}).items():
            if operation not in operations or right not in RIGHTS:
                errors.append(f"Unknown public operation/right declaration: {key}, {operation}, {right}.")
        if key[0] not in APPROVED_DOMAINS | {"global", "shared"} or key[1] not in APPROVED_DOMAINS | {"global", "shared"}:
            errors.append(f"Unknown owner in public edge: {key}.")
    findings: dict[tuple[str, str, str], Finding] = {}
    graph: dict[str, set[str]] = {}
    for source in scripts.values():
        graph[source.path] = implementation_targets(source, scripts, symbols)
        references = {symbols[name].path for name in set(re.findall(r"\b\w+\b", source.code)) if name in symbols}
        references.discard(source.path)
        for path in source.imports:
            if path.endswith(".gd"):
                if path not in scripts:
                    errors.append(f"{source.path}: unknown imported script target {path}.")
                else:
                    references.add(path)
            elif path.startswith("content/") and not (root / path).exists():
                errors.append(f"{source.path}: unknown imported asset target {path}.")
            elif path.startswith(("content/ui/", "content/scenes/")) and source.owner != "global":
                # Global panel/entry scene construction is not made legal by class-free assets.
                target = ScriptInfo(path, path, "global", "scenes", "@" + path, "", "")
                reason = _forbidden(source, target)
                if reason:
                    finding = Finding("forbidden-edge", source.stable_path, source.owner, target.symbol, "global", path, reason)
                    findings[finding.key] = finding
        for path in references:
            target = scripts[path]
            if source.owner == target.owner:
                continue
            reason = _forbidden(source, target)
            rule = "forbidden-edge" if reason else "undeclared-public-edge"
            edge = public.get((source.owner, target.owner, target.symbol))
            if not reason and edge is not None:
                names = [target.symbol] + [alias for alias, imported in source.aliases.items() if imported == target.path]
                instance_names = {name for name, typename in re.findall(r"\b(\w+)\s*:\s*(\w+)", source.code) if typename == target.symbol}
                instance_calls = {method for name in instance_names for method in re.findall(r"\b" + re.escape(name) + r"\s*\.\s*(\w+)\s*\(", source.code) if _method_owner(target, method, symbols)}
                calls = {method for name in names for method in re.findall(r"\b" + re.escape(name) + r"\s*\.\s*(\w+)\s*\(", source.code)}
                private_calls = sorted(method for method in calls | instance_calls if method.startswith("_"))
                if private_calls:
                    reason = "private cross-owner operation: " + ", ".join(private_calls)
                    rule = "private-api"
                else:
                    declared = set(edge.get("public_methods", []))
                    undeclared = (calls - declared - {"new"}) | (instance_calls - set(edge.get("public_instance_methods", [])))
                    missing_rights = {method for method in calls | instance_calls if edge.get("method_rights", {}).get(method, "read") not in edge["rights"]}
                    if undeclared or missing_rights:
                        reason = "operation is not declared/authorized: " + ", ".join(sorted(undeclared | missing_rights))
                        rule = "unauthorized-operation"
                    else:
                        continue
            if not reason:
                reason = "public declaration alone does not authorize this source-owner edge"
            finding = Finding(rule, source.stable_path, source.owner, target.symbol, target.owner, target.path, reason)
            findings[finding.key] = finding
    return list(findings.values()), graph, scripts, errors


def validate_dependencies(root: Path = ROOT, strict: bool = False) -> list[str]:
    """Check current code against explicit rights and exact, still-open legacy exemptions."""
    try:
        manifest = _json(root / "utils/domain_contracts.json", {"public_edges": []})
        plan = _json(root / "utils/domain_migration_map.json", {"files": []})
        baseline = _json(root / "utils/domain_dependency_baseline.json", {"entries": []})
        findings, graph, scripts, errors = analyze(root, manifest, plan)
    except (OSError, ValueError, KeyError, TypeError) as error:
        return [f"Invalid dependency metadata: {error}"]
    by_stable = {info.stable_path: info for info in scripts.values()}
    by_symbol = {info.symbol: info for info in scripts.values()}
    raw_graph = {path: set(targets) for path, targets in graph.items()}
    current = {finding.key: finding for finding in findings}
    exemptions: dict[tuple[str, str, str], dict] = {}
    for entry in baseline.get("entries", []):
        key = (entry.get("rule", ""), entry.get("source", ""), entry.get("target_symbol", ""))
        if key in exemptions:
            errors.append(f"Duplicate legacy exemption: {key}.")
        exemptions[key] = entry
        if strict:
            errors.append(f"Strict mode requires an empty legacy baseline: {key}.")
            continue
        tasks = list((root / "agent_tasks/refactoring_v2").glob(entry.get("removal_task", "") + "_*.md"))
        if not entry.get("source_owner") or not entry.get("reason") or len(tasks) != 1:
            errors.append(f"Legacy exemption requires exact source/owner/reason/removal task: {key}.")
            continue
        status = re.search(r"^Status:\s*\*\*([^*]+)\*\*", tasks[0].read_text(encoding="utf-8"), re.MULTILINE)
        if status is None or status.group(1).startswith("DONE"):
            errors.append(f"Expired legacy exemption after task {entry['removal_task']}: {key}.")
            continue
        source = by_stable.get(key[1])
        target = by_symbol.get(key[2])
        active = key in current if key[0] != "implementation-cycle" else source is not None and target is not None and _edge_in_cycle(raw_graph, source.path, target.path)
        if not active or source is None or source.owner != entry["source_owner"]:
            errors.append(f"Stale/mismatched legacy exemption must be removed: {key}.")
            continue
        if key[0] == "implementation-cycle" and not target:
            errors.append(f"Unknown cycle target: {key}.")
            continue
        if target and entry.get("target_path") != target.stable_path:
            errors.append(f"Mismatched exact legacy target path: {key}.")
            continue
        if source and target:
            graph[source.path].discard(target.path)
        current.pop(key, None)
    for finding in current.values():
        errors.append(f"{finding.source}: {finding.rule} -> {finding.target_symbol} ({finding.target_owner}): {finding.reason}.")
    found = _cycle(graph)
    if found:
        errors.append("Actual implementation cycle: " + " -> ".join([found[0][0]] + [target for _, target in found]))
    return errors


def capture_baseline(root: Path) -> list[str]:
    """Freeze current exact debt once before migration; default validation never expands this baseline."""
    if (root / "utils/domain_dependency_baseline.json").exists():
        return ["Legacy dependency baseline is already frozen; default/capture validation cannot expand it."]
    manifest = _json(root / "utils/domain_contracts.json", {"public_edges": []})
    plan = _json(root / "utils/domain_migration_map.json", {"files": []})
    findings, graph, scripts, errors = analyze(root, manifest, plan)
    if errors:
        return errors
    by_stable = {info.stable_path: info for info in scripts.values()}
    symbols = {info.symbol: info for info in scripts.values()}
    entries: list[dict] = []
    for finding in findings:
        source = by_stable[finding.source]
        target = symbols.get(finding.target_symbol)
        removal = _task_for(source, plan) if source.owner != "global" else _task_for(target, plan) if target else "31"
        entries.append(dict(rule=finding.rule, source=finding.source, source_owner=finding.source_owner, target_symbol=finding.target_symbol, target_path=finding.target_path, removal_task=removal, reason=finding.reason))
        if target:
            graph[source.path].discard(target.path)
    while found := _cycle(graph):
        source_path, target_path = found[0]
        source, target = scripts[source_path], scripts[target_path]
        removal = min(_task_for(scripts[node], plan) for edge in found for node in edge)
        entries.append(dict(rule="implementation-cycle", source=source.stable_path, source_owner=source.owner, target_symbol=target.symbol, target_path=target.path, removal_task=removal, reason="Exact pre-migration behavioral cycle; resolve responsibility before the earliest involved owner closes."))
        graph[source_path].discard(target_path)
    path = root / "utils/domain_dependency_baseline.json"
    path.write_text(json.dumps({"version": 1, "entries": sorted(entries, key=lambda row: (row["removal_task"], row["source"], row["target_symbol"], row["rule"]))}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return []


def prune_resolved(root: Path) -> list[str]:
    """Remove only resolved existing debt; this operation cannot authorize a new violation."""
    path = root / "utils/domain_dependency_baseline.json"
    baseline = _json(path, {"version": 1, "entries": []})
    manifest = _json(root / "utils/domain_contracts.json", {"public_edges": []})
    plan = _json(root / "utils/domain_migration_map.json", {"files": []})
    findings, graph, scripts, errors = analyze(root, manifest, plan)
    if errors:
        return errors
    current = {finding.key for finding in findings}
    by_stable = {info.stable_path: info for info in scripts.values()}
    by_symbol = {info.symbol: info for info in scripts.values()}
    retained: list[dict] = []
    for entry in baseline.get("entries", []):
        key = (entry["rule"], entry["source"], entry["target_symbol"])
        source, target = by_stable.get(key[1]), by_symbol.get(key[2])
        active = key in current if key[0] != "implementation-cycle" else source is not None and target is not None and _edge_in_cycle(graph, source.path, target.path)
        if active:
            retained.append(entry)
    removed = len(baseline.get("entries", [])) - len(retained)
    baseline["entries"] = retained
    path.write_text(json.dumps(baseline, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Resolved legacy exemptions removed: {removed}; remaining: {len(retained)}")
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--capture-baseline", action="store_true", help="freeze exact legacy debt before the first owner move")
    parser.add_argument("--prune-resolved", action="store_true", help="remove only resolved frozen legacy entries; never grants new access")
    args = parser.parse_args()
    root = args.root.resolve()
    errors = capture_baseline(root) if args.capture_baseline else prune_resolved(root) if args.prune_resolved else validate_dependencies(root, args.strict)
    if errors:
        print("Domain dependency validation: FAIL")
        for error in errors:
            print("- " + error)
        return 1
    print("Domain dependency validation: PASS" + (" (strict)" if args.strict else " (transition)"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
