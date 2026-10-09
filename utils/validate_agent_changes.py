#!/usr/bin/env python3
"""Incremental architecture smells for PVZ agents; not a replacement for GECS review.

Only added code is judged, with rename-aware Git baselines. Historical Godot UI
and large single-responsibility Systems do not automatically fail normal tasks.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import difflib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UI_NODE = re.compile(r"\b(?:Button|Label|PanelContainer|VBoxContainer|HBoxContainer|"
                     r"GridContainer|CenterContainer|ScrollContainer|Control|"
                     r"TabContainer|TextureRect|MarginContainer)\.new\s*\(")
GEN_SCRIPT = re.compile(r"\bGDScript\s*\.\s*new\s*\(")
FILE_WRITE = re.compile(r"\bFileAccess\s*\.\s*open\s*\([\s\S]{0,230}?"
                        r"\.(?:gd|tscn)[\"'][\s\S]{0,130}?FileAccess\s*\.\s*(?:WRITE|READ_WRITE)")
SAVE_SCENE = re.compile(r"\bResourceSaver\.save\s*\(")
NODE = re.compile(r"(?m)^\[node\s")


@dataclass(frozen=True)
class Finding:
    severity: str
    path: str
    reason: str


def is_runtime(path: str) -> bool:
    return path.startswith("content/") and path.endswith(".gd")


def is_authoring_tool(path: str) -> bool:
    return (path.startswith("utils/") and path.endswith((".py", ".gd"))
            and not path.startswith(("utils/validate_", "utils/check_")))


def added_code(current: str, previous: str | None) -> str:
    before, after = (previous or "").splitlines(), current.splitlines()
    ranges = difflib.SequenceMatcher(a=before, b=after, autojunk=False).get_opcodes()
    return "\n".join("\n".join(after[a:b]) for tag, _x, _y, a, b in ranges
                     if tag in ("insert", "replace"))


def inspect_file(path: str, current: str, previous: str | None) -> list[Finding]:
    findings: list[Finding] = []

    def flag(severity: str, reason: str) -> None:
        findings.append(Finding(severity, path, reason))

    new = previous is None
    added = "\n".join(line for line in added_code(current, previous).splitlines()
                      if not line.lstrip().startswith("#"))
    if not added:
        return findings

    if is_runtime(path):
        if GEN_SCRIPT.search(added):
            flag("ERROR", "runtime creates GDScript dynamically; authored code belongs in tracked .gd")
        if FILE_WRITE.search(added):
            flag("ERROR", "runtime writes .gd/.tscn source files")
        if SAVE_SCENE.search(added) and ".tscn" in current and "PackedScene.new" in current:
            flag("ERROR", "runtime writes authored PackedScene; use an editable .tscn")
        if path.startswith("content/ui/") and len(UI_NODE.findall(added)) >= 5:
            flag("REVIEW", "new persistent UI layout may be assembled in GDScript; prefer .tscn")
        if (new and len(current.splitlines()) > 700) or (
            not new and len(previous.splitlines()) >= 650
            and len(current.splitlines()) - len(previous.splitlines()) > 80
        ):
            flag("REVIEW", "new/expanding large script: prove one coherent responsibility, "
                 "especially System vs Service vs Observer; do not split by line count alone")

    if is_authoring_tool(path):
        if (re.search(r"\.(?:gd|tscn)\b", current)
                and re.search(r"\b(?:write_text|write_bytes|FileAccess\.open|ResourceSaver\.save)\b", added)):
            flag("REVIEW", "tool generates scripts/scenes: ensure native editable output "
                 "and no gameplay-runtime scaffolding")

    if path.startswith("content/") and path.endswith(".tscn") and new:
        if (len(NODE.findall(current)) == 1 and 'type="Script"' in current
                and path.startswith(("content/ui/", "content/scenes/"))):
            flag("REVIEW", "script-only root in authored level/UI: inspect Scene dock editability")
    return findings


def git(root: Path, *args: str, optional: bool = False) -> bytes | None:
    done = subprocess.run(["git", *args], cwd=root, capture_output=True, check=False)
    if done.returncode:
        if optional:
            return None
        raise RuntimeError(f"git {' '.join(args)}: {done.stderr.decode(errors='replace')[-240:]}")
    return done.stdout


def changed_files(root: Path, base: str, staged: bool) -> tuple[str, dict[str, str | None]]:
    sha = git(root, "rev-parse", "--verify", f"{base}^{{commit}}")
    assert sha is not None
    revision = sha.decode().strip()
    command = ["diff", "--name-status", "-z", "--find-renames", "--diff-filter=ACMR"]
    command.extend(["--cached", revision] if staged else [revision])
    raw = git(root, *command)
    assert raw is not None
    entries = [entry.decode("utf-8") for entry in raw.split(b"\x00") if entry]
    result: dict[str, str | None] = {}
    index = 0
    while index < len(entries):
        status = entries[index]
        index += 1
        if status.startswith("R"):
            previous, current = entries[index:index + 2]
            result[current] = previous
            index += 2
        else:
            current = entries[index]
            result[current] = None if status.startswith("A") else current
            index += 1
    if not staged:
        untracked = git(root, "ls-files", "--others", "--exclude-standard", "-z")
        assert untracked is not None
        for entry in untracked.split(b"\x00"):
            if entry:
                result[entry.decode("utf-8")] = None
    return revision, result


def scan(root: Path, base: str = "HEAD", staged: bool = False) -> tuple[int, list[Finding]]:
    revision, paths = changed_files(root, base, staged)
    findings: list[Finding] = []
    analyzed = 0
    for name, previous_path in sorted(paths.items()):
        if not (is_runtime(name) or is_authoring_tool(name)
                or name.startswith("content/") and name.endswith(".tscn")):
            continue
        if staged:
            content = git(root, "show", f":{name}", optional=True)
            if content is None:
                continue
            current = content.decode("utf-8-sig")
        else:
            location = root / name
            if not location.is_file():
                continue
            current = location.read_text(encoding="utf-8-sig")
        old_blob = git(root, "show", f"{revision}:{previous_path}", optional=True) if previous_path else None
        previous = old_blob.decode("utf-8-sig") if old_blob is not None else None
        findings.extend(inspect_file(name, current, previous))
        analyzed += 1
    return analyzed, findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--base", default="HEAD", help="commit to compare with (default HEAD)")
    parser.add_argument("--staged", action="store_true", help="inspect Git index, not unstaged edits")
    parser.add_argument("--report-only", action="store_true", help="audit; not PASS evidence")
    args = parser.parse_args(argv)
    try:
        count, findings = scan(args.root.resolve(), args.base, args.staged)
    except (OSError, UnicodeError, RuntimeError, ValueError) as error:
        print(f"NOT_RUN: agent architecture gate: {error}", file=sys.stderr)
        return 2
    for finding in findings:
        print(f"{finding.severity}: {finding.path}: {finding.reason}")
    if args.report_only:
        print(f"REPORT_ONLY: {count} inspected, {len(findings)} findings; NOT a validation PASS")
        return 0
    if findings:
        print(f"FAIL: {len(findings)} architecture findings across {count} changed files")
        return 1
    print(f"PASS: incremental architectural smells; {count} changed files (review still required)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
