#!/usr/bin/env python3
"""Check Refactoring v2 planning links, dependencies and the Phase 0 gate."""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path, PurePosixPath
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
SCORE_CATEGORIES = (
    "Programmer UX", "Designer UX", "Debugging UX", "AI-agent UX",
    "Content scalability", "Architecture clarity",
)
SCOPE_FILES = frozenset({
    "AGENTS.md", "content/ARCHITECTURE.md",
    "docs/project_core_architecture_proposal.md", "docs/persistence.md",
    "utils/validate_refactoring_preflight.py", "utils/validate_domain_structure.py",
    "utils/validate_project_structure.py", "utils/validate_architecture.py",
    "utils/validate_domain_dependencies.py",
    "tests/tools/test_validate_refactoring_preflight.py",
    "tests/tools/test_validate_domain_structure.py",
    "tests/tools/test_validate_project_structure.py",
    "tests/tools/test_validate_architecture.py",
    "tests/tools/test_validate_domain_dependencies.py",
})
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


def validate_phase0_paths(paths: list[str]) -> list[str]:
    """Check the authorized planning footprint, not the meaning of file contents."""
    errors: list[str] = []
    for path in paths:
        parts = PurePosixPath(path).parts
        if not parts or ".." in parts or "\\" in path or PurePosixPath(path).is_absolute():
            errors.append(f"invalid Phase 0 path: {path}")
            continue
        planning_doc = path.startswith("agent_tasks/refactoring_v2/") and path.endswith(".md")
        skill_doc = path.startswith(".agents/skills/") and path.endswith(".md")
        if path not in SCOPE_FILES and not planning_doc and not skill_doc:
            errors.append(f"outside authorized Phase 0 scope: {path}")
    return errors


def validate_git_scope(root: Path, commit: str | None = None) -> list[str]:
    """Inspect one commit or the index; unrelated unstaged edits are not included."""
    if commit is not None and not re.fullmatch(r"[0-9a-fA-F]{7,40}", commit):
        return ["Phase 0 commit must be a hexadecimal commit ID"]
    command = (
        ["git", "show", "--format=", "--name-only", "-z", "--no-renames", commit, "--"]
        if commit is not None
        else ["git", "diff", "--cached", "--name-only", "-z", "--no-renames", "--"]
    )
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, check=False, timeout=20)
    except (OSError, subprocess.TimeoutExpired) as error:
        return [f"cannot inspect Phase 0 git scope: {error}"]
    if result.returncode:
        return ["cannot inspect Phase 0 git scope: " + result.stderr.decode("utf-8", "replace").strip()]
    try:
        paths = [path for path in result.stdout.decode("utf-8").split("\0") if path]
    except UnicodeDecodeError:
        return ["Phase 0 git scope contains invalid UTF-8 paths"]
    return validate_phase0_paths(paths)


def validate(root: Path = ROOT, require_gate: bool = False) -> list[str]:
    """Return planning errors; this does not validate runtime implementation."""
    errors: list[str] = []
    task_root = root / "agent_tasks/refactoring_v2"
    roadmap_path = task_root / "README.md"
    if not roadmap_path.is_file():
        return ["Refactoring v2 README.md is missing"]

    roadmap = roadmap_path.read_text(encoding="utf-8")
    archive_root = root / "agent_tasks/completed/refactoring_v2"
    document_paths: dict[str, Path] = {}
    for directory in (task_root, archive_root):
        for path in sorted(directory.glob("*.md")):
            if not TASK_NAME.fullmatch(path.name):
                continue
            if path.name in document_paths:
                errors.append(f"duplicate task in active/archive directories: {path.name}")
                continue
            document_paths[path.name] = path
    documents = {
        name: path.read_text(encoding="utf-8") for name, path in document_paths.items()
    }
    # Archive links retain the same task identity and position in the dependency graph.
    order = [PurePosixPath(unquote(target)).name for target in ORDERED_LINK.findall(roadmap)]
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

    paths = [roadmap_path, *document_paths.values()]
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
        for name, document in {"README.md": roadmap, **documents}.items():
            if len(STATUS.findall(document)) != 1:
                errors.append(f"{name}: exactly one Status is required")
        for name in PREFLIGHT:
            status = STATUS.search(documents.get(name, ""))
            if status is None or status.group(1) != "DONE":
                errors.append(f"{name}: Phase 0 audit is not DONE")
        gate_document = documents.get(PREFLIGHT[-1], "")
        gate = RESULT.search(gate_document)
        roadmap_status = STATUS.search(roadmap)
        if len(RESULT.findall(gate_document)) != 1:
            errors.append("readiness gate has no explicit final Result")
        elif roadmap_status is None or roadmap_status.group(1) != gate.group(1):
            errors.append("README Status does not match readiness Result")
        if gate is not None:
            ready = gate.group(1) == "READY_FOR_IMPLEMENTATION"
            target_status = (
                "PREFLIGHT_TARGET_APPROVED — IMPLEMENTATION_PENDING"
                if ready else "PREFLIGHT_NOT_READY — IMPLEMENTATION_BLOCKED"
            )
            proposal = proposal_path.read_text(encoding="utf-8") if proposal_path.is_file() else ""
            if STATUS.findall(proposal) != [target_status]:
                errors.append("proposal Status does not match readiness Result")
            next_tasks = re.findall(r"^Next task: `([^`]+)`$", roadmap, re.MULTILINE)
            planning_actions = re.findall(r"^Next planning action: (.+)$", roadmap, re.MULTILINE)
            blockers = re.findall(r"^Blockers: (.+)$", gate_document, re.MULTILINE)
            if ready:
                if next_tasks != ["01_architecture_contract.md"] or planning_actions:
                    errors.append("READY roadmap must name 01_architecture_contract.md as the sole next task")
                if blockers != ["NONE"]:
                    errors.append("READY gate must explicitly have Blockers: NONE")
            elif (
                next_tasks or len(planning_actions) != 1
                or not planning_actions[0].strip()
                or len(blockers) != 1 or blockers[0].strip() in ("", "NONE", "TBD", "-")
            ):
                errors.append("NOT_READY gate requires blockers and a next planning action, without implementation next task")
        for category in SCORE_CATEGORIES:
            rows = re.findall(
                rf"^\| {re.escape(category)} \| (\d+)/10 \| ([^\n|]*) \|$",
                gate_document, re.MULTILINE,
            )
            if len(rows) != 1 or not 1 <= int(rows[0][0]) <= 10:
                errors.append(f"readiness scorecard missing or invalid: {category}")
            elif int(rows[0][0]) < 8 and rows[0][1].strip() in ("", "-", "TBD"):
                errors.append(f"score below 8 needs an explanation: {category}")
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
    parser.add_argument("--phase0-commit", action="append", default=[], metavar="COMMIT")
    parser.add_argument("--check-staged-scope", action="store_true")
    arguments = parser.parse_args()
    errors = validate(arguments.root.resolve(), arguments.require_gate)
    for commit in arguments.phase0_commit:
        errors.extend(validate_git_scope(arguments.root.resolve(), commit))
    if arguments.check_staged_scope:
        errors.extend(validate_git_scope(arguments.root.resolve()))
    if errors:
        print("Refactoring preflight validation: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1
    print("Refactoring preflight validation: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
