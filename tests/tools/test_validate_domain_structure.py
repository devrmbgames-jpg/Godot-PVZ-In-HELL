#!/usr/bin/env python3
"""Regression tests for the vertical-domain structure validator."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
import sys

ROOT: Path = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "utils"))

from validate_domain_structure import validate_domain_structure


class DomainStructureValidatorTest(unittest.TestCase):
    def _root(self) -> tuple[tempfile.TemporaryDirectory[str], Path]:
        temporary = tempfile.TemporaryDirectory()
        root = Path(temporary.name)
        (root / "content").mkdir()
        return temporary, root

    def test_accepts_canonical_domain_roles(self) -> None:
        temporary, root = self._root()
        self.addCleanup(temporary.cleanup)

        component_dir = root / "content/domains/combat/components"
        component_dir.mkdir(parents=True)
        (component_dir / "c_health.gd").write_text(
            "extends Component\nclass_name C_Health\n",
            encoding="utf-8",
        )

        self.assertEqual([], validate_domain_structure(root))

    def test_rejects_misspelled_role_directory(self) -> None:
        temporary, root = self._root()
        self.addCleanup(temporary.cleanup)

        (root / "content/domains/combat/camponent").mkdir(parents=True)

        errors = validate_domain_structure(root)

        self.assertTrue(any("camponent" in error for error in errors))
        self.assertTrue(any("components" in error for error in errors))

    def test_rejects_wrong_role_prefix(self) -> None:
        temporary, root = self._root()
        self.addCleanup(temporary.cleanup)

        component_dir = root / "content/domains/combat/components"
        component_dir.mkdir(parents=True)
        (component_dir / "health.gd").write_text(
            "extends Component\nclass_name Health\n",
            encoding="utf-8",
        )

        errors = validate_domain_structure(root)

        self.assertTrue(any("filename prefix 'c_'" in error for error in errors))
        self.assertTrue(any("class_name 'Health'" in error for error in errors))

    def test_strict_mode_rejects_legacy_horizontal_root(self) -> None:
        temporary, root = self._root()
        self.addCleanup(temporary.cleanup)

        (root / "content/domains").mkdir()
        (root / "content/components").mkdir()

        errors = validate_domain_structure(root, strict=True)

        self.assertTrue(any("legacy horizontal gameplay root" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
