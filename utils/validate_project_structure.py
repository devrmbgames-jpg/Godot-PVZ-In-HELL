#!/usr/bin/env python3
"""Validate repository structure and explicit project path references without external dependencies."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT: Path = Path(__file__).resolve().parents[1]

ROLE_RULES: tuple[tuple[str, str, str], ...] = (
    ("content/components", "c_", "C_"),
    ("content/systems", "s_", "S_"),
    ("content/entities", "e_", "E_"),
    ("content/observers", "o_", "O_"),
    ("content/definitions", "def_", "DEF_"),
)

ROLE_EXCEPTIONS: set[str] = {
    "content/definitions/definition.gd",
}

TEXT_RESOURCE_ROOTS: tuple[str, ...] = (
    "content",
    "tests",
    "utils",
)

TEXT_RESOURCE_SUFFIXES: set[str] = {
    ".gd",
    ".tscn",
    ".tres",
    ".res",
    ".cfg",
}

CLASS_NAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
RES_PATH_RE = re.compile(r"""["'](res://[^"']+)["']""")
MARKDOWN_LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
TASK_HEADING_RE = re.compile(r"^#\s+(R\d+(?:\.\d+)?)\b", re.MULTILINE)
TASK_DEPENDENCIES_RE = re.compile(r"^Зависимости:\s*(.+)$", re.MULTILINE)
IMPLEMENTATION_ID_RE = re.compile(r"\bR\d+(?:\.\d+)?\b")


def _relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return ""


def _check_role_placement(errors: list[str]) -> None:
    forbidden_core: Path = ROOT / "content/core"
    if forbidden_core.exists():
        errors.append("content/core/ is forbidden; use contracts/, services/, systems/, or the owning subsystem.")

    for root_name, file_prefix, class_prefix in ROLE_RULES:
        role_root: Path = ROOT / root_name
        if not role_root.exists():
            continue

        for script_path in sorted(role_root.rglob("*.gd")):
            relative: str = _relative(script_path)
            if relative in ROLE_EXCEPTIONS:
                continue

            if not script_path.name.startswith(file_prefix):
                errors.append(
                    f"{relative}: expected filename prefix '{file_prefix}' for files under {root_name}/."
                )

            match = CLASS_NAME_RE.search(_read_text(script_path))
            if match is not None and not match.group(1).startswith(class_prefix):
                errors.append(
                    f"{relative}: class_name {match.group(1)!r} should use '{class_prefix}' role prefix."
                )


def _check_uid_pairs(errors: list[str]) -> None:
    content_root: Path = ROOT / "content"
    if not content_root.exists():
        return

    for uid_path in sorted(content_root.rglob("*.gd.uid")):
        script_path: Path = uid_path.with_suffix("")
        if not script_path.exists():
            errors.append(f"{_relative(uid_path)}: orphan script UID; {_relative(script_path)} is missing.")


def _iter_project_text_resources() -> list[Path]:
    files: list[Path] = [ROOT / "project.godot"]

    for root_name in TEXT_RESOURCE_ROOTS:
        search_root: Path = ROOT / root_name
        if not search_root.exists():
            continue

        for path in search_root.rglob("*"):
            if path.is_file() and path.suffix in TEXT_RESOURCE_SUFFIXES:
                files.append(path)

    return files


def _check_res_paths(errors: list[str]) -> None:
    for source_path in _iter_project_text_resources():
        text: str = _read_text(source_path)
        if not text:
            continue

        for match in RES_PATH_RE.finditer(text):
            resource_path: str = match.group(1)
            if any(token in resource_path for token in ("%", "{", "}")):
                continue

            file_part: str = resource_path.split("::", 1)[0]
            local_path: Path = ROOT / file_part.removeprefix("res://")
            if not local_path.exists():
                errors.append(
                    f"{_relative(source_path)}: broken resource path {resource_path!r}."
                )


def _iter_markdown_files() -> list[Path]:
    files: list[Path] = [ROOT / "PROJECT_INDEX.md"]

    for root_name in ("agent_tasks", "docs/roadmap"):
        root_path: Path = ROOT / root_name
        if root_path.exists():
            files.extend(sorted(root_path.glob("*.md")))

    return files


def _check_markdown_links(errors: list[str]) -> None:
    for source_path in _iter_markdown_files():
        if not source_path.exists():
            errors.append(f"{_relative(source_path)} is missing.")
            continue

        for raw_target in MARKDOWN_LINK_RE.findall(_read_text(source_path)):
            target: str = raw_target.strip()
            if (
                not target
                or target.startswith("#")
                or "://" in target
                or target.startswith("mailto:")
            ):
                continue

            target = unquote(target.split("#", 1)[0])
            if not target:
                continue

            local_path: Path = (source_path.parent / target).resolve()
            try:
                local_path.relative_to(ROOT.resolve())
            except ValueError:
                errors.append(
                    f"{_relative(source_path)}: link escapes repository root: {raw_target!r}."
                )
                continue

            if not local_path.exists():
                errors.append(
                    f"{_relative(source_path)}: broken local link {raw_target!r}."
                )


def _check_task_dependencies(errors: list[str]) -> None:
    task_root: Path = ROOT / "agent_tasks"
    task_files: list[Path] = sorted(task_root.glob("roadmap_*.md"))
    known_ids: set[str] = set()
    task_ids: dict[str, Path] = {}

    for task_path in task_files:
        text: str = _read_text(task_path)
        match = TASK_HEADING_RE.search(text)
        if match is None:
            errors.append(f"{_relative(task_path)}: missing canonical Rxx/Rxx.x heading.")
            continue

        task_id: str = match.group(1)
        if task_id in task_ids:
            errors.append(
                f"{_relative(task_path)}: duplicate implementation ID {task_id}; "
                f"already used by {_relative(task_ids[task_id])}."
            )
            continue

        task_ids[task_id] = task_path
        known_ids.add(task_id)

        if "RM" in text:
            errors.append(
                f"{_relative(task_path)}: RM-prefixed task IDs are not canonical; use Rxx/Rxx.x."
            )

    history_path: Path = ROOT / "task_history.md"
    if history_path.exists():
        known_ids.update(IMPLEMENTATION_ID_RE.findall(_read_text(history_path)))

    for task_id, task_path in task_ids.items():
        text: str = _read_text(task_path)
        dependencies_match = TASK_DEPENDENCIES_RE.search(text)
        if dependencies_match is None:
            continue

        dependencies: list[str] = IMPLEMENTATION_ID_RE.findall(dependencies_match.group(1))
        for dependency in dependencies:
            if dependency not in known_ids:
                errors.append(
                    f"{_relative(task_path)}: dependency {dependency} has no planned task "
                    "and is not recorded as completed in task_history.md."
                )

def _git_output(*args: str) -> list[str]:
    try:
        result = subprocess.run(
            ["git", *args],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        return []

    if result.returncode != 0:
        return []

    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def _check_staged_addons(errors: list[str]) -> None:
    staged_addons: list[str] = _git_output("diff", "--cached", "--name-only", "--", "addons")
    for path in staged_addons:
        errors.append(f"{path}: staged addon/dependency change is forbidden by default.")


def main() -> int:
    errors: list[str] = []

    _check_role_placement(errors)
    _check_uid_pairs(errors)
    _check_res_paths(errors)
    _check_markdown_links(errors)
    _check_task_dependencies(errors)
    _check_staged_addons(errors)

    if errors:
        print("Project structure validation: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Project structure validation: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
