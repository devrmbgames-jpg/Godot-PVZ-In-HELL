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
    ("content/relationships", "r_", "R_"),
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
TASK_STATUS_RE = re.compile(
    r"^Status:\s*\*\*(PLANNED|IN_PROGRESS|DEFERRED|BLOCKED|OWNER_QA|DONE)\*\*$",
    re.MULTILINE,
)
IMPLEMENTATION_ID_RE = re.compile(r"\bR\d+(?:\.\d+)?\b")
BEHAVIOR_PRIVATE_ROOTS: tuple[str, ...] = (
    "content/entities",
    "content/ui",
    "content/services",
    "content/systems",
    "content/observers",
)

ONREADY_VAR_RE = re.compile(
    r"^\s*@onready\s+var\s+([A-Za-z_][A-Za-z0-9_]*)",
    re.MULTILINE,
)
TOP_LEVEL_VAR_RE = re.compile(
    r"^(?:static\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)",
)
TOP_LEVEL_ONREADY_RE = re.compile(
    r"^@onready\s+var\s+([A-Za-z_][A-Za-z0-9_]*)",
)
RESOURCE_HEADER_RE = re.compile(r'^\[gd_resource\s+type="([^"]+)"([^]]*)\]', re.MULTILINE)
SCRIPT_CLASS_RE = re.compile(r'\bscript_class="([^"]+)"')

RESOURCE_TYPE_PREFIXES: dict[str, str] = {
    "Theme": "theme_",
    "StyleBox": "style_",
    "StyleBoxEmpty": "style_",
    "StyleBoxFlat": "style_",
    "StyleBoxLine": "style_",
    "StyleBoxTexture": "style_",
    "StandardMaterial3D": "mat_",
    "ShaderMaterial": "mat_",
    "CanvasItemMaterial": "mat_",
    "ParticleProcessMaterial": "mat_",
    "PhysicsMaterial": "mat_",
    "ORMMaterial3D": "mat_",
    "ArrayMesh": "mesh_",
    "BoxMesh": "mesh_",
    "CapsuleMesh": "mesh_",
    "CylinderMesh": "mesh_",
    "PlaneMesh": "mesh_",
    "PrismMesh": "mesh_",
    "QuadMesh": "mesh_",
    "SphereMesh": "mesh_",
    "TextMesh": "mesh_",
    "TorusMesh": "mesh_",
    "GradientTexture1D": "tex_",
    "GradientTexture2D": "tex_",
    "NoiseTexture2D": "tex_",
    "AtlasTexture": "tex_",
    "FontFile": "font_",
    "SystemFont": "font_",
    "FontVariation": "font_",
    "Environment": "env_",
    "LabelSettings": "label_",
    "NavigationMesh": "navmesh_",
    "FastNoiseLite": "noise_",
    "BoxShape2D": "shape_",
    "CapsuleShape2D": "shape_",
    "CircleShape2D": "shape_",
    "ConcavePolygonShape2D": "shape_",
    "ConvexPolygonShape2D": "shape_",
    "RectangleShape2D": "shape_",
    "SegmentShape2D": "shape_",
    "WorldBoundaryShape2D": "shape_",
    "BoxShape3D": "shape_",
    "CapsuleShape3D": "shape_",
    "ConcavePolygonShape3D": "shape_",
    "ConvexPolygonShape3D": "shape_",
    "CylinderShape3D": "shape_",
    "HeightMapShape3D": "shape_",
    "SeparationRayShape3D": "shape_",
    "SphereShape3D": "shape_",
    "WorldBoundaryShape3D": "shape_",
    "Curve": "curve_",
    "Curve2D": "curve_",
    "Curve3D": "curve_",
    "Gradient": "grad_",
    "Animation": "anim_",
    "AnimationLibrary": "animlib_",
}

RESOURCE_PREFIX_EXCEPTIONS: set[str] = {
    "default_bus_layout.tres",
}

RELATIONSHIP_COMPONENT_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"\bRelationship\.new\(\s*(C_[A-Za-z_][A-Za-z0-9_]*)"),
    re.compile(r"\.relation\s+(?:is|as)\s+(C_[A-Za-z_][A-Za-z0-9_]*)"),
    re.compile(r"\bon_relationship_(?:added|removed)\(\[\s*(C_[A-Za-z_][A-Za-z0-9_]*)"),
)


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



def _check_private_member_naming(errors: list[str]) -> None:
    """Enforce private runtime caches/state in behavior/glue/UI code."""
    content_root: Path = ROOT / "content"
    if content_root.exists():
        for script_path in sorted(content_root.rglob("*.gd")):
            relative: str = _relative(script_path)
            text: str = _read_text(script_path)
            for match in ONREADY_VAR_RE.finditer(text):
                name: str = match.group(1)
                if not name.startswith("_"):
                    errors.append(
                        f"{relative}: @onready cache {name!r} must be private and start with '_'."
                    )

    for root_name in BEHAVIOR_PRIVATE_ROOTS:
        root_path: Path = ROOT / root_name
        if not root_path.exists():
            continue

        for script_path in sorted(root_path.rglob("*.gd")):
            relative: str = _relative(script_path)
            for line_number, raw_line in enumerate(_read_text(script_path).splitlines(), start=1):
                if not raw_line or raw_line[0].isspace():
                    continue
                if raw_line.startswith("@export"):
                    continue

                match = TOP_LEVEL_ONREADY_RE.match(raw_line)
                if match is None:
                    match = TOP_LEVEL_VAR_RE.match(raw_line)
                if match is None:
                    continue

                name: str = match.group(1)
                if not name.startswith("_"):
                    errors.append(
                        f"{relative}:{line_number}: non-exported member state {name!r} "
                        "must be private and start with '_'."
                    )


def _resource_prefix(path: Path, text: str) -> str | None:
    relative: str = _relative(path)
    if relative.startswith("content/definitions/"):
        return "def_"

    header = RESOURCE_HEADER_RE.search(text)
    if header is None:
        return None

    script_class_match = SCRIPT_CLASS_RE.search(header.group(2))
    if script_class_match is not None and script_class_match.group(1).startswith("DEF_"):
        return "def_"

    return RESOURCE_TYPE_PREFIXES.get(header.group(1))


def _check_resource_file_naming(errors: list[str]) -> None:
    roots: tuple[str, ...] = ("content", "materials")
    for root_name in roots:
        root_path: Path = ROOT / root_name
        if not root_path.exists():
            continue
        for resource_path in sorted(root_path.rglob("*.tres")):
            relative: str = _relative(resource_path)
            if relative in RESOURCE_PREFIX_EXCEPTIONS or resource_path.name in RESOURCE_PREFIX_EXCEPTIONS:
                continue
            prefix: str | None = _resource_prefix(resource_path, _read_text(resource_path))
            if prefix is not None and not resource_path.name.startswith(prefix):
                errors.append(
                    f"{relative}: expected resource filename prefix {prefix!r}."
                )


def _check_relationship_role_usage(errors: list[str]) -> None:
    """Reject legacy C_* types used as project-owned GECS relationship payloads."""
    for root_name in ("content", "tests"):
        root_path: Path = ROOT / root_name
        if not root_path.exists():
            continue

        for script_path in sorted(root_path.rglob("*.gd")):
            text: str = _read_text(script_path)
            for pattern in RELATIONSHIP_COMPONENT_PATTERNS:
                for match in pattern.finditer(text):
                    errors.append(
                        f"{_relative(script_path)}: relationship payload {match.group(1)!r} "
                        "must use an R_* class under content/relationships/."
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
            if file_part.endswith("/") or file_part.startswith("res://tests/artifacts/"):
                continue
            local_path: Path = ROOT / file_part.removeprefix("res://")
            if not local_path.exists():
                errors.append(
                    f"{_relative(source_path)}: broken resource path {resource_path!r}."
                )


def _iter_markdown_files() -> list[Path]:
    files: list[Path] = [ROOT / "PROJECT_INDEX.md", ROOT / "task_history.md"]

    for root_name in ("agent_tasks", "qa_tasks", "docs/roadmap", "task_history_archive"):
        root_path: Path = ROOT / root_name
        if root_path.exists():
            files.extend(sorted(root_path.rglob("*.md")))

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


def _check_task_state_contract(errors: list[str]) -> None:
    task_root: Path = ROOT / "agent_tasks"
    if not task_root.exists():
        return

    index_path: Path = task_root / "CONTEXT.md"
    if not index_path.exists():
        errors.append("agent_tasks/CONTEXT.md is missing; task queue/status index is required.")

    for task_path in sorted(task_root.glob("*.md")):
        if task_path.name in {"README.md", "CONTEXT.md"}:
            continue

        text: str = _read_text(task_path)
        if TASK_STATUS_RE.search(text) is None:
            errors.append(
                f"{_relative(task_path)}: missing normalized task status "
                "(PLANNED/IN_PROGRESS/DEFERRED/BLOCKED/OWNER_QA/DONE)."
            )
        if "## Task state" not in text:
            errors.append(f"{_relative(task_path)}: missing authoritative '## Task state' block.")
        for heading in ("### Goal", "### Current", "### Validation", "### Owner QA / blockers"):
            if heading not in text:
                errors.append(f"{_relative(task_path)}: task state is missing {heading!r}.")


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
    archive_root: Path = ROOT / "task_history_archive"
    if archive_root.exists():
        for archive_path in sorted(archive_root.glob("*.md")):
            known_ids.update(IMPLEMENTATION_ID_RE.findall(_read_text(archive_path)))

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
                    "and is not recorded as completed in task_history.md or its archives."
                )


def _check_main_level_system_groups(errors: list[str]) -> None:
    """Every runtime System under a main-level SystemGroup must keep its coarse tick group."""
    scene_path: Path = ROOT / "content/scenes/main_level.tscn"
    if not scene_path.exists():
        return

    text: str = _read_text(scene_path)
    world_instance = re.search(r'^\[node name="World"[^\n]*instance=ExtResource\("([^"]+)"\)', text, re.MULTILINE)
    if world_instance:
        declaration = re.search(r'^\[ext_resource type="PackedScene"[^\n]*path="res://([^"]+)"[^\n]*\bid="' + re.escape(world_instance.group(1)) + r'"\]', text, re.MULTILINE)
        if declaration is None:
            errors.append("main_level: shared World instance has no PackedScene declaration.")
            return
        scene_path = ROOT / declaration.group(1)
        text = _read_text(scene_path)
    lines: list[str] = text.splitlines()
    group_scripts: set[str] = set(re.findall(
        r'^\[ext_resource type="Script"[^\n]*path="res://addons/gecs/lib/system_group.gd"[^\n]*id="([^"]+)"',
        text, re.MULTILINE,
    ))
    automatic_groups: set[str] = set()
    for node in re.finditer(r'^\[node ([^\n]+)\]\n(.*?)(?=^\[node |\Z)', text, re.MULTILINE | re.DOTALL):
        header, body = node.groups()
        name = re.search(r'name="([^"]+)"', header)
        parent = re.search(r'parent="([^"]+)"', header)
        script = re.search(r'^script = ExtResource\("([^"]+)"\)', body, re.MULTILINE)
        if name and parent and script and script.group(1) in group_scripts and not re.search(r'^auto_group = false$', body, re.MULTILINE):
            automatic_groups.add(f'{parent.group(1)}/{name.group(1)}')
    for index, line in enumerate(lines):
        match = re.match(
            r'^\[node name="(S_[^"]+)" type="Node" parent="((?:World/)?Systems/([^"]+))"[^]]*\]$',
            line,
        )
        if match is None:
            continue

        system_name: str = match.group(1)
        system_parent: str = match.group(2)
        expected_group: str = match.group(3)
        actual_group: str | None = None

        for body_line in lines[index + 1 :]:
            if body_line.startswith("[node "):
                break
            group_match = re.match(r'^group = &?"([^"]*)"$', body_line)
            if group_match is not None:
                actual_group = group_match.group(1)
                break

        # GECS SystemGroup._enter_tree assigns omitted groups before World registration.
        if actual_group is None and system_parent in automatic_groups:
            continue
        if actual_group != expected_group:
            errors.append(
                f"{scene_path.relative_to(ROOT)}: {system_name} must keep "
                f'group=&"{expected_group}" (found {actual_group!r}).'
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
    _check_private_member_naming(errors)
    _check_resource_file_naming(errors)
    _check_relationship_role_usage(errors)
    _check_uid_pairs(errors)
    _check_res_paths(errors)
    _check_markdown_links(errors)
    _check_task_state_contract(errors)
    _check_task_dependencies(errors)
    _check_main_level_system_groups(errors)
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
