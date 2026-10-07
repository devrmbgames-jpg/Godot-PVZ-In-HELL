#!/usr/bin/env python3
"""Check Refactoring v2 planning links, dependencies and the Phase 0 gate."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
TASK_NAME = re.compile(r"^\d{2}_.+\.md$")
TASK_REFERENCE = re.compile(r"\b\d{2}_[a-z0-9_]+\.md\b")
ORDERED_LINK = re.compile(r"^\d+\. \[[^\]]+\]\(([^)]+\.md)\)$", re.MULTILINE)
LOCAL_LINK = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
STATUS = re.compile(r"^Status: \*\*([^*]+)\*\*$", re.MULTILINE)
RESULT = re.compile(
    r"^Result: \*\*(READY_FOR_IMPLEMENTATION|NOT_READY_FOR_IMPLEMENTATION)\*\*$",
    re.MULTILINE,
)
DEPENDENCY_LABEL = "Зависимости:"
PREFLIGHT = tuple(
    f"00_0{index}_{suffix}.md"
    for index, suffix in enumerate(
        (
            "architecture_coherence_audit",
            "usability_authoring_audit",
            "simplification_reference_audit",
            "migration_persistence_validation_audit",
            "preflight_readiness_gate",
        ),
        start=1,
    )
)


def dependency_references(document: str) -> set[str]:
    """Read only the dependency declaration, not acceptance/next-task links."""
    lines = document.splitlines()
    for index, line in enumerate(lines):
        if not line.startswith(DEPENDENCY_LABEL):
            continue

        declaration = [line]
        for continuation in lines[index + 1 :]:
            if not continuation.strip():
                break
            declaration.append(continuation)
        return set(TASK_REFERENCE.findall("\n".join(declaration)))
    return set()


def validate(root: Path = ROOT, require_gate: bool = False) -> list[str]:
    """Return planning errors; this does not validate runtime implementation."""
    errors: list[str] = []
    task_root = root / "agent_tasks/refactoring_v2"
    roadmap_path = task_root / "README.md"
    if not roadmap_path.is_file():
        return ["Refactoring v2 README.md is missing"]

    roadmap = roadmap_path.read_text(encoding="utf-8")
    documents = {
        path.name: path.read_text(encoding="utf-8")
        for path in sorted(task_root.glob("*.md"))
        if TASK_NAME.fullmatch(path.name)
    }
    order = ORDERED_LINK.findall(roadmap)
    if len(order) != len(set(order)):
        errors.append("README execution order contains duplicate task entries")
    for missing in sorted(documents.keys() - set(order)):
        errors.append(f"README execution order omits {missing}")
    for unknown in sorted(set(order) - documents.keys()):
        errors.append(f"README execution order names unknown task {unknown}")
    if tuple(order[:5]) != PREFLIGHT:
        errors.append("Phase 0 order must be exactly 00_01 through 00_05")

    positions = {name: index for index, name in enumerate(order)}
    graph: dict[str, set[str]] = {}
    for name, document in documents.items():
        dependencies = dependency_references(document)
        graph[name] = dependencies
        if DEPENDENCY_LABEL not in document:
            errors.append(f"{name}: dependency declaration missing")
        if name != PREFLIGHT[0] and not dependencies:
            errors.append(f"{name}: explicit task prerequisites missing")
        for prerequisite in sorted(dependencies):
            if prerequisite not in documents:
                errors.append(f"{name}: unknown prerequisite {prerequisite}")
            elif positions.get(prerequisite, -1) >= positions.get(name, -1):
                errors.append(f"{name}: prerequisite {prerequisite} does not appear earlier")

    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visiting:
            errors.append(f"dependency cycle reaches {name}")
            return
        if name in visited:
            return
        visiting.add(name)
        for dependency in sorted(graph.get(name, set())):
            if dependency in graph:
                visit(dependency)
        visiting.remove(name)
        visited.add(name)

    for name in graph:
        visit(name)

    paths = [roadmap_path, *(task_root / name for name in documents)]
    proposal_path = root / "docs/project_core_architecture_proposal.md"
    if proposal_path.is_file():
        paths.append(proposal_path)
    else:
        errors.append("target architecture proposal is missing")

    for path in paths:
        document = path.read_text(encoding="utf-8")
        if "\ufffd" in document or re.search(r"\?{3,}", document):
            errors.append(f"{path.name}: possible text encoding corruption")
        for target in LOCAL_LINK.findall(document):
            if "://" in target or target.startswith("#"):
                continue
            target_path = unquote(target.split("#", 1)[0].strip("<>"))
            if target_path:
                resolved = (path.parent / target_path).resolve()
                if not resolved.is_relative_to(root.resolve()):
                    errors.append(f"{path.name}: local link escapes repository {target}")
                elif not resolved.is_file():
                    errors.append(f"{path.name}: broken local link {target}")

    if require_gate:
        for name in PREFLIGHT:
            status = STATUS.search(documents.get(name, ""))
            if status is None or status.group(1) != "DONE":
                errors.append(f"{name}: Phase 0 audit is not DONE")
        gate = RESULT.search(documents.get(PREFLIGHT[-1], ""))
        roadmap_status = STATUS.search(roadmap)
        if gate is None:
            errors.append("readiness gate has no explicit final Result")
        elif roadmap_status is None or roadmap_status.group(1) != gate.group(1):
            errors.append("README Status does not match readiness Result")
        for name, document in documents.items():
            if name in PREFLIGHT:
                continue
            status = STATUS.search(document)
            if status is None or status.group(1) != "PLANNED":
                errors.append(f"{name}: implementation task started during preflight")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--require-gate", action="store_true")
    arguments = parser.parse_args()
    errors = validate(arguments.root.resolve(), arguments.require_gate)
    if errors:
        print("Refactoring preflight validation: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Refactoring preflight validation: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
