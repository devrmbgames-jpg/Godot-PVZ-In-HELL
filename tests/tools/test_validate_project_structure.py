"""Regression coverage for structure checks across horizontal and vertical layouts."""

from __future__ import annotations

import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "utils"))

import validate_project_structure as validator


class ProjectStructureValidatorTest(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        root_patch = patch.object(validator, "ROOT", self.root)
        root_patch.start()
        self.addCleanup(root_patch.stop)

    def _write(self, relative: str, text: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def _private_errors(self) -> list[str]:
        errors: list[str] = []
        validator._check_private_member_naming(errors)
        return errors

    def test_behavior_members_are_checked_in_all_supported_layouts(self) -> None:
        paths = (
            "content/services/flow_service.gd",
            "content/ui/panel.gd",
            "content/domains/npc/services/flow_service.gd",
            "content/domains/npc/systems/s_flow.gd",
            "content/domains/npc/observers/o_flow.gd",
            "content/domains/npc/entities/e_actor.gd",
            "content/domains/npc/ui/panel.gd",
            "content/shared/services/lookup_service.gd",
            "content/shared/entities/e_proxy.gd",
        )
        for path in paths:
            with self.subTest(path=path):
                self._write(path, "extends Node\nvar runtime_cache: int = 0\n")
                self.assertTrue(any(path in error for error in self._private_errors()))

    def test_data_contracts_and_exports_remain_public(self) -> None:
        for path in (
            "content/components/c_state.gd",
            "content/domains/npc/components/c_state.gd",
            "content/domains/npc/relationships/r_binding.gd",
            "content/shared/contracts/snapshot.gd",
            "content/shared/definitions/def_profile.gd",
        ):
            self._write(path, "extends Resource\nvar state: int = 0\n")
        self._write(
            "content/domains/npc/services/flow_service.gd",
            "extends Node\nvar _cache: int = 0\n@export var capacity: int = 1\n"
            "func step() -> void:\n\tvar local_state: int = 0\n",
        )
        self.assertEqual([], self._private_errors())

    def test_onready_members_are_private_even_in_data_roles(self) -> None:
        path = "content/shared/contracts/cache.gd"
        self._write(path, "extends Node\n@onready var cache: Node = self\n")
        self.assertTrue(any("@onready cache 'cache'" in error for error in self._private_errors()))

    def test_nested_folder_name_does_not_reclassify_a_contract(self) -> None:
        self._write("content/domains/npc/contracts/services/snapshot.gd", "var state: int = 0\n")
        self.assertEqual([], self._private_errors())

    def test_definition_resource_naming_does_not_require_script_class_header(self) -> None:
        paths = (
            "content/definitions/npc/profile.tres",
            "content/domains/npc/definitions/profile.tres",
            "content/shared/definitions/profile.tres",
        )
        for path in paths:
            self._write(path, '[gd_resource type="Resource" format=3]\n')
        errors: list[str] = []
        validator._check_resource_file_naming(errors)
        for path in paths:
            with self.subTest(path=path):
                self.assertTrue(any(path in error and "'def_'" in error for error in errors))

    def test_valid_definition_and_engine_resource_prefixes(self) -> None:
        self._write(
            "content/domains/npc/definitions/def_profile.tres",
            '[gd_resource type="Resource" format=3]\n',
        )
        self._write(
            "content/shared/scenes/mat_actor.tres",
            '[gd_resource type="StandardMaterial3D" format=3]\n',
        )
        errors: list[str] = []
        validator._check_resource_file_naming(errors)
        self.assertEqual([], errors)

    def test_legacy_prefix_checks_and_definition_base_exception_remain(self) -> None:
        self._write("content/components/health.gd", "extends Component\nclass_name Health\n")
        self._write(
            "content/definitions/definition.gd", "extends Resource\nclass_name GameDefinition\n"
        )
        errors: list[str] = []
        validator._check_role_placement(errors)
        self.assertTrue(any("filename prefix 'c_'" in error for error in errors))
        self.assertTrue(any("'C_' role prefix" in error for error in errors))
        self.assertFalse(any("definition.gd:" in error for error in errors))

    def test_entry_point_integrates_domain_prefix_validation(self) -> None:
        for path in ("README.md", "AGENTS.md", "PROJECT_INDEX.md", "content/ARCHITECTURE.md"):
            self._write(path, "# Fixture\n")
        self._write("project.godot", "[application]\n")
        self._write("content/domains/npc/components/health.gd", "class_name Health\n")
        output = io.StringIO()
        with patch.object(validator, "_git_output", return_value=[]), contextlib.redirect_stdout(output):
            result = validator.main()
        self.assertEqual(1, result)
        self.assertIn("filename prefix 'c_'", output.getvalue())
        self.assertIn("class_name 'Health'", output.getvalue())

    def test_entry_point_accepts_valid_domain_and_shared_content(self) -> None:
        for path in ("README.md", "AGENTS.md", "PROJECT_INDEX.md", "content/ARCHITECTURE.md"):
            self._write(path, "# Fixture\n")
        self._write("project.godot", "[application]\n")
        self._write(
            "content/domains/npc/systems/s_flow.gd",
            "extends System\nclass_name S_Flow\nvar _elapsed: float = 0.0\n",
        )
        self._write("content/shared/components/c_state.gd", "class_name C_State\nvar state: int\n")
        self._write(
            "content/domains/npc/definitions/def_profile.tres",
            '[gd_resource type="Resource" format=3]\n',
        )
        output = io.StringIO()
        with patch.object(validator, "_git_output", return_value=[]), contextlib.redirect_stdout(output):
            result = validator.main()
        self.assertEqual(0, result, output.getvalue())


if __name__ == "__main__":
    unittest.main()
