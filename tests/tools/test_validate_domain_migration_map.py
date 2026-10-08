#!/usr/bin/env python3
"""Regression coverage for coherent owner moves and authored UID preservation."""
from __future__ import annotations
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "utils"))
from validate_domain_migration_map import validate_migration_map
from validate_domain_structure import APPROVED_DOMAINS


class MigrationMapTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = "content/components/gameplay/c_health.gd"
        self.target = "content/domains/combat/components/c_health.gd"
        path = self.root / self.source
        path.parent.mkdir(parents=True)
        path.write_text("extends Component\nclass_name C_Health\n", encoding="utf-8")
        self.row = {"source": self.source, "target": self.target, "owner": "combat", "role": "components", "task": "30", "symbol": "C_Health"}
        self.plan = {"version": 1, "owners": sorted(APPROVED_DOMAINS), "roots": ["components"], "files": [self.row]}

    def _check(self) -> list[str]:
        path = self.root / "map.json"
        path.write_text(json.dumps(self.plan), encoding="utf-8")
        return validate_migration_map(self.root, path)

    def test_accepts_pending_and_completed_single_owner_move(self) -> None:
        self.assertEqual([], self._check())
        target = self.root / self.target
        target.parent.mkdir(parents=True)
        (self.root / self.source).rename(target)
        self.assertEqual([], self._check())

    def test_rejects_missing_legacy_gameplay_coverage(self) -> None:
        (self.root / self.source).with_name("c_other.gd").write_text("extends Component", encoding="utf-8")
        self.assertTrue(any("missing from the migration map" in error for error in self._check()))

    def test_rejects_parallel_old_and_new_files(self) -> None:
        target = self.root / self.target
        target.parent.mkdir(parents=True)
        target.write_text("extends Component\nclass_name C_Health", encoding="utf-8")
        self.assertTrue(any("both old and new" in error for error in self._check()))

    def test_rejects_target_collision_and_wrong_canonical_role(self) -> None:
        self.plan["files"].append(dict(self.row))
        self.assertTrue(any("Duplicate migration target" in error for error in self._check()))
        self.plan["files"] = [self.row]
        self.row["role"] = "camponent"
        self.assertTrue(any("canonical owner/role" in error for error in self._check()))

    def test_uid_must_follow_asset_and_preserve_its_original_value(self) -> None:
        uid = (self.root / self.source).with_name("c_health.gd.uid")
        uid.write_text("uid://original", encoding="utf-8")
        self.assertTrue(any("UID is missing" in error for error in self._check()))
        uid_row = dict(self.row, source=self.source + ".uid", target=self.target + ".uid", uid="uid://original")
        uid_row.pop("symbol")
        self.plan["files"].append(uid_row)
        self.assertEqual([], self._check())
        uid_row["target"] = "content/domains/combat/components/wrong.gd.uid"
        self.assertTrue(any("UID must follow" in error for error in self._check()))
        uid_row["target"] = self.target + ".uid"
        uid.write_text("uid://replaced", encoding="utf-8")
        self.assertTrue(any("original authored UID changed" in error for error in self._check()))

    def test_rejects_changed_native_resource_header_uid(self) -> None:
        source = "content/entities/body.tscn"
        path = self.root / source
        path.parent.mkdir(parents=True)
        path.write_text('[gd_scene format=3 uid="uid://changed"]', encoding="utf-8")
        self.plan["files"].append({"source": source, "target": "content/domains/combat/entities/body.tscn", "owner": "combat", "role": "entities", "task": "30", "uid": "uid://original"})
        self.assertTrue(any("original authored UID changed" in error for error in self._check()))


if __name__ == "__main__":
    unittest.main()
