#!/usr/bin/env python3
"""Local, non-mutating GDQuest format/lint gate with GECS-friendly class names.

Normal mode validates new lines in edited legacy scripts, and entire new scripts.
--strict checks complete files for Phase 3. --changed chooses local Git changes.
The CLI linter's generic class-name rule is replaced by our role-aware check.
"""
from __future__ import annotations

import argparse
import difflib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PASCAL = re.compile(r"^[A-Z][a-zA-Z0-9]*$")
ROLE = re.compile(r"^(?:C|S|O|R|E|DEF|ET|UI)_[A-Z][a-zA-Z0-9]*$")
CLASS = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)\b")
LINT = re.compile(r"^.+?:(\d+):([a-z][a-z0-9-]*):(warning|error):\s*(.*)$", re.I)
LINE_LIMIT = 100
FORMATTER_VERSION = "0.26.2"
OWNED_ADDONS = ("addons/pvz_ai_tools/", "addons/project_entity_traits/")
GENERATED_ROOTS = ("tests/artifacts/",)
SOURCE_ROOTS = ("content", "tests", "utils", *(path.rstrip("/") for path in OWNED_ADDONS))


def project_owned(path: str) -> bool:
    normalized = path.replace("\\", "/")
    return normalized.endswith(".gd") and not normalized.startswith(GENERATED_ROOTS) and (
        not normalized.startswith("addons/") or normalized.startswith(OWNED_ADDONS)
    )


def project_files(root: Path) -> list[str]:
    """Scan only authored source roots; generated data and vendored addons stay excluded."""
    return sorted({path.relative_to(root).as_posix() for source in SOURCE_ROOTS
                   for path in (root / source).rglob("*.gd")
                   if path.is_file() and path.resolve().is_relative_to(root)
                   and project_owned(path.relative_to(root).as_posix())})


def verify_formatter_version(binary: str) -> None:
    result = subprocess.run([binary, "--version"], capture_output=True, text=True,
                            errors="replace", check=False)
    if result.returncode or result.stdout.strip() != f"gdscript-formatter {FORMATTER_VERSION}":
        raise RuntimeError(f"Expected gdscript-formatter {FORMATTER_VERSION}; got "
                           f"{(result.stdout + result.stderr).strip()[:160]}")


def manifest_files(root: Path, task: str) -> list[str]:
    """Reject missing, overlapping or stale Phase 3 ownership before selecting a batch."""
    data = json.loads((root / "utils/gdscript_style_manifest.json").read_text(encoding="utf-8"))
    tasks = data.get("tasks", {})
    if data.get("schema_version") != 1 or set(tasks) != {str(n) for n in range(61, 66)}:
        raise ValueError("Invalid style manifest schema/task set")
    combined: list[str] = []
    for paths in tasks.values():
        if not isinstance(paths, list) or any(not isinstance(path, str) for path in paths):
            raise ValueError("Invalid style manifest paths")
        combined.extend(paths)
    if len(combined) != len(set(combined)) or set(combined) != set(project_files(root)):
        raise ValueError("Style manifest must own every project script exactly once")
    return tasks[task]


def run_git(root: Path, *args: str, allow_failure: bool = False) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(["git", *args], cwd=root, capture_output=True, check=False)
    if result.returncode and not allow_failure:
        raise RuntimeError(f"git {' '.join(args)} failed: {result.stderr.decode(errors='replace')[-300:]}")
    return result


def changed_origins(root: Path, base: str) -> dict[str, str | None]:
    """Map current paths to base paths; tracked renames must not become 'new'."""
    commit = run_git(root, "rev-parse", "--verify", f"{base}^{{commit}}").stdout.decode().strip()
    raw = run_git(root, "diff", "--name-status", "--find-renames", "--diff-filter=ACMR",
                  "-z", commit).stdout
    parts = [item.decode().replace("\\", "/") for item in raw.split(b"\x00") if item]
    result: dict[str, str | None] = {}
    i = 0
    while i < len(parts):
        status = parts[i]
        i += 1
        if status.startswith("R"):
            old, new = parts[i:i + 2]
            result[new] = old
            i += 2
        else:
            path = parts[i]
            result[path] = None if status.startswith("A") else path
            i += 1
    untracked = run_git(root, "ls-files", "--others", "--exclude-standard", "-z").stdout
    for item in untracked.split(b"\x00"):
        if item:
            result[item.decode().replace("\\", "/")] = None
    return result


def changed_files(root: Path, base: str) -> list[str]:
    return sorted(changed_origins(root, base))


def previous_text(root: Path, path: str, base: str) -> str | None:
    commit = run_git(root, "rev-parse", "--verify", f"{base}^{{commit}}").stdout.decode().strip()
    result = run_git(root, "show", f"{commit}:{path}", allow_failure=True)
    return None if result.returncode else result.stdout.decode("utf-8")


def added_lines(before: str | None, after: str) -> set[int]:
    if before is None:
        return set(range(1, len(after.splitlines()) + 1))
    old, new = before.splitlines(), after.splitlines()
    return {idx + 1 for op, _a, _b, first, last in difflib.SequenceMatcher(
        a=old, b=new, autojunk=False
    ).get_opcodes() if op in ("insert", "replace") for idx in range(first, last)}


def acceptable_class_name(name: str) -> bool:
    return bool(PASCAL.fullmatch(name) or ROLE.fullmatch(name))


def formatter_binary(root: Path) -> str | None:
    """Use explicit local binary/CLI, without downloading or changing user tools."""
    override = os.environ.get("GDSCRIPT_FORMATTER_BIN", "").strip()
    if override:
        binary = shutil.which(override)
        if binary is None:
            raise RuntimeError(f"GDSCRIPT_FORMATTER_BIN does not exist or is not executable: {override}")
        return binary
    for name in ("gdscript-formatter.exe", "gdscript-formatter"):
        candidate = root / ".bin" / name
        if candidate.is_file():
            return str(candidate)
    return shutil.which("gdscript-formatter")


def local_issues(path: str, source: str, numbers: set[int]) -> list[str]:
    issues: list[str] = []
    for index, line in enumerate(source.splitlines(), 1):
        if index not in numbers:
            continue
        class_match = CLASS.match(line)
        if class_match and not acceptable_class_name(class_match.group(1)):
            issues.append(f"{path}:{index}: invalid class_name {class_match.group(1)!r}; use PascalCase or a declared GECS role prefix")
        if line.rstrip(" \t") != line:
            issues.append(f"{path}:{index}: trailing whitespace")
        if re.match(r"^ +\S", line):
            issues.append(f"{path}:{index}: spaces used for indentation; use tabs")
        if len(line.expandtabs(4)) > LINE_LIMIT and not line.lstrip().startswith("#"):
            issues.append(f"{path}:{index}: exceeds {LINE_LIMIT} columns")
    return issues


def selected_lint_issues(output: str, numbers: set[int], strict: bool) -> tuple[list[str], bool]:
    """Return relevant diagnostics; a non-parseable output must not be treated as PASS."""
    issues: list[str] = []
    recognized = False
    for line in output.splitlines():
        match = LINT.match(line.strip())
        if match:
            recognized = True
            if strict or int(match.group(1)) in numbers:
                issues.append(line.strip())
    return issues, recognized


def inspect_file(root: Path, path: str, previous: str | None, formatter: str | None,
                 strict: bool = False) -> tuple[list[str], bool]:
    source = (root / path).read_text(encoding="utf-8-sig")
    numbers = added_lines(previous, source)
    if not numbers and not strict:
        return [], False
    issues = local_issues(path, source, numbers if not strict else set(range(1, len(source.splitlines()) + 1)))
    if formatter is None:
        return issues, True
    lint_cmd = [formatter, "lint", path, "--max-line-length", str(LINE_LIMIT), "--disable", "class-name"]
    lint = subprocess.run(lint_cmd, cwd=root, capture_output=True, text=True, errors="replace", check=False)
    output = "\n".join(part for part in (lint.stdout, lint.stderr) if part)
    findings, recognized = selected_lint_issues(output, numbers, strict or previous is None)
    issues.extend(findings)
    if lint.returncode and not recognized:
        issues.append(f"{path}: linter failed ({lint.returncode}): {output.strip()[:250]}")
    if lint.returncode == 0 and findings:
        issues.append(f"{path}: linter returned 0 despite relevant diagnostics")
    if previous is None or strict:
        # --verify-structure validates the formatter's output but still writes by default.
        # Keep --check in the same invocation so this gate never changes authored files.
        checked = subprocess.run([formatter, "--check", "--verify-structure", path], cwd=root,
                                 capture_output=True, text=True, errors="replace", check=False)
        if checked.returncode:
            detail = (checked.stdout + checked.stderr).strip().splitlines()
            issues.append(f"{path}: formatter check failed: {(detail or ['no detail'])[0][:220]}")
    return issues, False


def main(argv: list[str] | None = None) -> int:
    args_parser = argparse.ArgumentParser(description=__doc__)
    args_parser.add_argument("paths", nargs="*", help="GDScript paths (pre-commit supplies staged names)")
    args_parser.add_argument("--changed", action="store_true", help="check edited/untracked project files")
    args_parser.add_argument("--all", action="store_true", help="strict full-project authored GDScript check")
    args_parser.add_argument("--task", choices=[str(n) for n in range(61, 66)],
                             help="strict complete batch from the Phase 3 ownership manifest")
    args_parser.add_argument("--base", default="HEAD", help="commit baseline for changed/new lines")
    args_parser.add_argument("--strict", action="store_true", help="full-file formatting and lint")
    args_parser.add_argument("--root", type=Path, default=ROOT, help="testable project root")
    args = args_parser.parse_args(argv)
    root = args.root.resolve()
    if not args.paths and not args.changed and not args.all and not args.task:
        args_parser.error("specify GDScript paths, --changed, --all or --task")
    if (args.all or args.task) and (args.paths or args.changed or (args.all and args.task)):
        args_parser.error("--all/--task cannot be combined with another selection")
    strict = args.strict or args.all or bool(args.task)
    try:
        origins = changed_origins(root, args.base) if args.changed or not strict else {}
        paths = set(project_files(root) if args.all else args.paths)
        if args.task:
            paths = set(manifest_files(root, args.task))
        if args.changed:
            paths.update(origins)
        normalized: set[str] = set()
        for path in paths:
            if not path.endswith(".gd"):
                continue
            candidate = (root / path.replace("\\", "/")).resolve()
            if not candidate.is_relative_to(root):
                raise ValueError("Outside-workspace script: " + path)
            relative = candidate.relative_to(root).as_posix()
            if not project_owned(relative):
                continue
            if not candidate.is_file():
                raise ValueError("Missing script: " + path)
            normalized.add(relative)
        paths = normalized
        if not paths:
            if args.all:
                raise ValueError("Full-project authored GDScript scope is empty")
            print("PASS: no changed project-owned GDScript")
            return 0
        binary = formatter_binary(root)
        if binary is not None:
            verify_formatter_version(binary)
        errors: list[str] = []
        missing = False
        for path in sorted(paths):
            old_path = origins.get(path, path)
            old = previous_text(root, old_path, args.base) if old_path and not strict else None
            results, skipped = inspect_file(root, path, old, binary, strict)
            errors.extend(results)
            missing |= skipped
        for message in errors:
            print("FAIL:", message)
        if missing:
            print("NOT_RUN: gdscript-formatter not on PATH; install the pinned GDQuest CLI or provide it on PATH")
        if errors:
            return 1
        if missing:
            return 2
        print(f"PASS: GDQuest formatter/lint + GECS role naming ({len(paths)} file(s), {'strict' if strict else 'incremental'})")
        return 0
    except (OSError, UnicodeError, RuntimeError, ValueError) as error:
        print(f"NOT_RUN: GDScript style gate: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
