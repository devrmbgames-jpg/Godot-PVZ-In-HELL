#!/usr/bin/env python3
"""Run the optional project GDScript formatter checks for files supplied by pre-commit."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT: Path = Path(__file__).resolve().parents[1]


def _project_gd_files(arguments: list[str]) -> list[str]:
    result: list[str] = []

    for raw_path in arguments:
        path: Path = Path(raw_path)
        normalized: str = path.as_posix()

        if path.suffix != ".gd":
            continue
        if normalized.startswith("addons/"):
            continue
        if not (ROOT / path).exists():
            continue

        result.append(normalized)

    return result


def main() -> int:
    files: list[str] = _project_gd_files(sys.argv[1:])
    if not files:
        return 0

    formatter: str | None = shutil.which("gdscript-formatter")
    if formatter is None:
        print("GDScript formatter: SKIP (gdscript-formatter is not available)")
        return 0

    for path in files:
        for arguments in (("--check", path), ("--verify-structure", path)):
            result = subprocess.run(
                [formatter, *arguments],
                cwd=ROOT,
                check=False,
            )
            if result.returncode != 0:
                return result.returncode

    print(f"GDScript formatter: PASS ({len(files)} file(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
