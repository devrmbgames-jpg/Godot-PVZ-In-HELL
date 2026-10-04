"""Check formatting/documentation edits without ignoring strings or indentation."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent


def code_and_strings(source: str) -> tuple[list[str], list[str]]:
    """Remove comments/blank lines, retaining exact code and string contents."""
    output: list[str] = []
    strings: list[str] = []
    index = 0
    while index < len(source):
        char = source[index]
        if char == "#":
            end = source.find("\n", index)
            index = len(source) if end < 0 else end
        elif char in ("'", '"'):
            delimiter = char * 3 if source.startswith(char * 3, index) else char
            start = index
            index += len(delimiter)
            while index < len(source):
                if source[index] == "\\":
                    index += 2
                elif source.startswith(delimiter, index):
                    index += len(delimiter)
                    break
                else:
                    index += 1
            output.append(f"<string:{len(strings)}>")
            strings.append(source[start:index])
        else:
            output.append(char)
            index += 1
    lines = [line.rstrip() for line in "".join(output).splitlines() if line.strip()]
    return lines, strings


def self_test() -> None:
    """Exercise quotes, escaped quotes, multiline literals and indentation."""
    original = 'var value: String = "# text" # old\n\treturn value\n'
    documented = '## Contract\nvar value: String = "# text" # new\n\n\treturn value\n'
    assert code_and_strings(original) == code_and_strings(documented)
    assert code_and_strings(original) != code_and_strings(original.replace('\treturn', 'return'))
    literal = 'var text = """first\n# inside\n\nlast"""\n'
    assert code_and_strings(literal) != code_and_strings(literal.replace('\n\nlast', '\nlast'))
    escaped = 'var text = "escaped \\" quote # literal" # outside\n'
    assert code_and_strings(escaped)[1] == ['"escaped \\" quote # literal"']


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="HEAD", help="Committed source to compare.")
    parser.add_argument("--mode", choices=("spacing", "comments"), default="comments")
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()
    self_test()

    paths = args.paths or subprocess.check_output(
        ["git", "diff", "--name-only", args.base, "--", "*.gd"], cwd=ROOT, text=True
    ).splitlines()
    checked = 0
    failures: list[str] = []
    for relative in paths:
        if relative.startswith("addons/") or not relative.endswith(".gd"):
            continue
        original = subprocess.check_output(
            ["git", "show", f"{args.base}:{relative}"], cwd=ROOT
        ).decode("utf-8")
        current = (ROOT / relative).read_text(encoding="utf-8")
        checked += 1
        identical = code_and_strings(original) == code_and_strings(current)
        if args.mode == "spacing":
            identical = identical and (
                [line for line in original.splitlines() if line.strip()]
                == [line for line in current.splitlines() if line.strip()]
            )
        if not identical:
            failures.append(relative)
    for relative in failures:
        print(f"FAIL: executable source changed: {relative}")
    print(f"Nonbehavior validation: {checked} scripts, {len(failures)} failures ({args.mode})")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
