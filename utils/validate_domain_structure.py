#!/usr/bin/env python3
"""Validate canonical vertical-domain layout for project-owned gameplay code."""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from pathlib import Path

ROOT: Path = Path(__file__).resolve().parents[1]

CANONICAL_ROLE_DIRS: frozenset[str] = frozenset(
    {
        "ai",
        "authoring",
        "components",
        "contracts",
        "debug",
        "definitions",
        "dialogue",
        "entities",
        "observers",
        "presentation",
        "relationships",
        "rules",
        "scenes",
        "services",
        "solvers",
        "systems",
        "ui",
    }
)

ROLE_SCRIPT_RULES: dict[str, tuple[str, str]] = {
    "components": ("c_", "C_"),
    "relationships": ("r_", "R_"),
    "systems": ("s_", "S_"),
    "observers": ("o_", "O_"),
    "entities": ("e_", "E_"),
    "definitions": ("def_", "DEF_"),
}

# These roots represent the old horizontal gameplay layout. They remain legal
# while the migration is in progress and become errors in --strict mode.
LEGACY_HORIZONTAL_ROOTS: tuple[str, ...] = (
    "ai",
    "components",
    "contracts",
    "definitions",
    "dialogue",
    "entities",
    "navigation",
    "observers",
    "relationships",
    "services",
    "systems",
)

DOMAIN_NAME_RE = re.compile(r"^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$")
CLASS_NAME_RE = re.compile(
    r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)",
    re.MULTILINE,
)

ALLOWED_CONTAINER_FILES: frozenset[str] = frozenset(
    {
        ".gdignore",
        "README.md",
    }
)


def _relative(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return ""


def _closest_role(name: str) -> str | None:
    matches: list[str] = difflib.get_close_matches(
        name,
        sorted(CANONICAL_ROLE_DIRS),
        n=1,
        cutoff=0.55,
    )
    return matches[0] if matches else None


def _check_role_container(
    root: Path,
    owner_root: Path,
    errors: list[str],
) -> None:
    """Validate canonical role folders under one domain/shared container."""
    for child in sorted(owner_root.iterdir()):
        if child.is_file():
            if child.name not in ALLOWED_CONTAINER_FILES:
                errors.append(
                    f"{_relative(root, child)}: files must live inside a canonical role "
                    "directory; only README.md/.gdignore are allowed at this level."
                )
            continue

        if not child.is_dir():
            continue

        role_name: str = child.name
        if role_name not in CANONICAL_ROLE_DIRS:
            suggestion: str | None = _closest_role(role_name)
            hint: str = f"; did you mean '{suggestion}'?" if suggestion is not None else ""
            errors.append(
                f"{_relative(root, child)}/: unknown domain role directory {role_name!r}{hint}. "
                f"Use one of: {', '.join(sorted(CANONICAL_ROLE_DIRS))}."
            )
            continue

        rule: tuple[str, str] | None = ROLE_SCRIPT_RULES.get(role_name)
        if rule is None:
            continue

        filename_prefix, class_prefix = rule
        for script_path in sorted(child.rglob("*.gd")):
            relative: str = _relative(root, script_path)
            if not script_path.name.startswith(filename_prefix):
                errors.append(
                    f"{relative}: scripts under {role_name}/ must use filename prefix "
                    f"{filename_prefix!r}."
                )

            class_match = CLASS_NAME_RE.search(_read_text(script_path))
            if class_match is not None and not class_match.group(1).startswith(class_prefix):
                errors.append(
                    f"{relative}: class_name {class_match.group(1)!r} must use "
                    f"{class_prefix!r} under {role_name}/."
                )


def validate_domain_structure(root: Path = ROOT, strict: bool = False) -> list[str]:
    """Return domain-layout violations without printing or exiting."""
    errors: list[str] = []
    content_root: Path = root / "content"
    domains_root: Path = content_root / "domains"
    shared_root: Path = content_root / "shared"

    if domains_root.exists():
        for child in sorted(domains_root.iterdir()):
            if child.is_file():
                if child.name not in ALLOWED_CONTAINER_FILES:
                    errors.append(
                        f"{_relative(root, child)}: content/domains/ may contain only "
                        "domain directories plus README.md/.gdignore."
                    )
                continue

            if not child.is_dir():
                continue

            domain_name: str = child.name
            if DOMAIN_NAME_RE.fullmatch(domain_name) is None:
                errors.append(
                    f"{_relative(root, child)}/: domain name must be lower_snake_case."
                )
                continue

            if domain_name in CANONICAL_ROLE_DIRS:
                errors.append(
                    f"{_relative(root, child)}/: domain name collides with canonical "
                    f"role directory {domain_name!r}."
                )

            _check_role_container(root, child, errors)

    elif strict:
        errors.append(
            "content/domains/ is missing; strict vertical-domain validation requires it."
        )

    if shared_root.exists():
        _check_role_container(root, shared_root, errors)

    if strict:
        for legacy_name in LEGACY_HORIZONTAL_ROOTS:
            legacy_path: Path = content_root / legacy_name
            if legacy_path.exists():
                errors.append(
                    f"{_relative(root, legacy_path)}/: legacy horizontal gameplay root is "
                    "forbidden in strict domain mode; move ownership into content/domains/"
                    "<domain>/ or content/shared/."
                )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate canonical vertical-domain repository structure."
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="also require content/domains/ and reject legacy horizontal gameplay roots",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=ROOT,
        help="repository root; primarily useful for validator tests",
    )
    args = parser.parse_args()

    root: Path = args.root.resolve()
    errors: list[str] = validate_domain_structure(root, strict=args.strict)

    if errors:
        print("Domain structure validation: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    mode: str = "strict" if args.strict else "transition"
    print(f"Domain structure validation: PASS ({mode})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
