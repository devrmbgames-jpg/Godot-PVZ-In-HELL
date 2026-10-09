#!/usr/bin/env python3
"""Validate detached authored content and retain native console and JSON evidence."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPLETE_MARKER = "CONTENT_DOCTOR_COMPLETE"
DIAGNOSTIC = re.compile(r"^(?:SCRIPT ERROR:|ERROR:|WARNING:)", re.MULTILINE)


def diagnostic_failures(console: str) -> tuple[list[str], list[str]]:
    """Only the owner's specified Godot 4.7.1 shutdown retention can be deferred."""
    before, marker, after = console.partition(COMPLETE_MARKER)
    failures = [line for line in before.splitlines() if DIAGNOSTIC.match(line)]
    deferred: list[str] = []
    retained = re.findall(r"^Leaked instance: ([A-Za-z0-9_]+):", after, re.MULTILINE)
    allowed_classes = {"GDScript", "GDScriptNativeClass", "Resource"}
    only_allowed_instances = bool(retained) and set(retained) <= allowed_classes
    known_engine = bool(marker) and "Godot Engine v4.7.1." in before
    rid_retention = bool(re.search(r"^ERROR: \d+ RID allocations .*leaked at exit\.$", after, re.MULTILINE))
    for line in after.splitlines():
        if not DIAGNOSTIC.match(line):
            continue
        resource_retention = bool(re.fullmatch(r"WARNING: \d+ resources still in use at exit.*", line))
        object_retention = line.startswith("WARNING: ObjectDB instances leaked at exit") and only_allowed_instances
        native_retention = (
            bool(re.fullmatch(r"ERROR: \d+ RID allocations .*leaked at exit\.", line))
            or (rid_retention and line.startswith("ERROR: Pages in use exist at exit in PagedAllocator"))
        )
        if known_engine and (resource_retention or object_retention or native_retention):
            deferred.append(line)
        else:
            failures.append(line)
    # Plain Node/Object retention is a lifecycle defect even if Godot omits a warning prefix.
    if set(retained) - allowed_classes:
        failures.append("Shutdown retained unexpected instance classes: " + ", ".join(sorted(set(retained) - allowed_classes)))
    return failures, deferred


def run_content_doctor(engine: Path | None = None) -> int:
    executable = engine or ROOT / ".bin/Godot_v4.7.1-stable_win64_console.exe"
    if not executable.is_file():
        print(f"Content Doctor: NOT_RUN (Godot executable missing: {executable})")
        return 2
    report_path = ROOT / ".artifacts/content_doctor.json"
    console_path = ROOT / "tests/artifacts/content_doctor.log"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    console_path.parent.mkdir(parents=True, exist_ok=True)
    # Prevent a failed new process from presenting a previous run's successful JSON.
    report_path.unlink(missing_ok=True)
    started = time.perf_counter()
    process = subprocess.run(
        [str(executable), "--headless", "--path", str(ROOT), "--script",
         "utils/content_doctor.gd", "--", str(report_path)],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", check=False,
    )
    console_path.write_text(process.stdout, encoding="utf-8")
    failures, deferred = diagnostic_failures(process.stdout)
    if COMPLETE_MARKER not in process.stdout or not report_path.is_file():
        failures.append("Native content scan did not complete or produce its report")
        report: dict = {}
    else:
        try:
            report = json.loads(report_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as error:
            failures.append(f"Invalid native content report: {error}")
            report = {}
    if deferred:
        print(f"Content Doctor shutdown: KNOWN_ENGINE_LIMITATION / DEFERRED ({len(deferred)} diagnostics; log retained)")
    passed = process.returncode == 0 and report.get("valid") is True and not failures
    print(f"Content Doctor: {'PASS' if passed else 'FAIL'} "
          f"({report.get('scenes', 0)} scenes, {report.get('dialogues', 0)} dialogues, "
          f"{report.get('errors', 0)} errors, {report.get('review_required', 0)} review gates; "
          f"{time.perf_counter() - started:.2f}s)")
    for issue in report.get("issues", []):
        print(f"- {issue['severity']} {issue['code']}: {issue['source']} / {issue['field']}: {issue['message']}")
    for failure in failures:
        print(f"- {failure}")
    if process.returncode != 0 and not failures and not report.get("issues"):
        print(f"- Native process exited with code {process.returncode}")
    print(f"Content Doctor evidence: {report_path.relative_to(ROOT)}, {console_path.relative_to(ROOT)}")
    return 0 if passed else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, help="Godot 4.7.1 console executable")
    arguments = parser.parse_args()
    return run_content_doctor(arguments.godot)


if __name__ == "__main__":
    sys.exit(main())
