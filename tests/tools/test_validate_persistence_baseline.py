"""Regression fixtures for closed save inventory and captured subresource paths."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "utils"))
from validate_persistence_baseline import inventory, validate


class PersistenceBaselineTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.codec = self.write("content/domains/persistence/services/save_data_codec.gd",
                                'static var _component_fields = {\n C_Health: C_Health.SAVE_FIELDS,\n}\n'
                                'static var _record_types: Array[Script] = [MoneyOperation]\n')
        self.write("content/components/c_health.gd", 'class_name C_Health\nconst SAVE_FIELDS: Array[String] = ["current"]\n')
        self.write("content/contracts/money_operation.gd", "class_name MoneyOperation\n")
        self.write("content/domains/persistence/services/autosave_store.gd", "const SCHEMA_VERSION: int = 2\n")
        self.write("content/definitions/supply.tres", "[gd_resource]\n")
        self.fixture = self.write("tests/fixtures/refactoring_v2/current_snapshot.variant",
                                  '{"definition": "res://content/definitions/supply.tres::Books"}')
        self.manifest = self.write("tests/fixtures/refactoring_v2/save_visible_paths.json",
                                   json.dumps(dict(schema=2, **inventory(self.root),
                                                   snapshot_paths=["res://content/definitions/supply.tres::Books"])))

    def write(self, path: str, text: str) -> Path:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text, encoding="utf-8")
        return destination

    def test_inline_definition_file_is_resolved(self) -> None:
        self.assertEqual([], validate(self.root))

    def test_codec_field_change_requires_explicit_baseline_decision(self) -> None:
        contract = self.root / "content/components/c_health.gd"
        contract.write_text(contract.read_text().replace('"current"', '"current", "base"'), encoding="utf-8")
        self.assertTrue(validate(self.root))

    def test_component_move_is_visible_to_schema_inventory(self) -> None:
        (self.root / "content/components/c_health.gd").rename(self.root / "content/c_health.gd")
        self.assertTrue(validate(self.root))

    def test_schema_change_and_missing_fixture_are_rejected(self) -> None:
        self.write("content/domains/persistence/services/autosave_store.gd", "const SCHEMA_VERSION: int = 3\n")
        self.fixture.unlink()
        self.assertEqual(2, len(validate(self.root)))

    def test_uninventoried_serialized_path_is_rejected(self) -> None:
        self.fixture.write_text('{"definition": "res://content/definitions/new.tres"}', encoding="utf-8")
        self.assertTrue(validate(self.root))


if __name__ == "__main__":
    unittest.main()
