#!/usr/bin/env python3
"""Focused domain access/cycle tests; no GDScript compiler or engine fixture is required."""
from __future__ import annotations
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "utils"))
from validate_domain_dependencies import validate_dependencies, capture_baseline


class DependencyTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / "utils").mkdir()
        self.edges: list[dict] = []

    def _script(self, owner: str, role: str, filename: str, text: str) -> str:
        path = f"content/domains/{owner}/{role}/{filename}" if owner not in ["shared", "global"] else f"content/shared/{role}/{filename}" if owner == "shared" else f"content/ui/{filename}"
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
        return path

    def _public(self, source: str, owner: str, symbol: str, path: str, methods: list[str] | None = None) -> None:
        self.edges.append({"source_owner": source, "target_owner": owner, "symbol": symbol, "path": path, "rights": ["read", "query", "request", "subscribe"], "public_methods": methods or [], "method_rights": {method: "request" for method in methods or []}})

    def _metadata(self) -> None:
        (self.root / "utils/domain_contracts.json").write_text(json.dumps({"version": 1, "public_edges": self.edges}), encoding="utf-8")

    def _check(self, strict: bool = False) -> list[str]:
        self._metadata()
        return validate_dependencies(self.root, strict)

    def _pair(self, body: str) -> tuple[str, str]:
        target = self._script("combat", "contracts", "damage_request.gd", "extends RefCounted\nclass_name DamageRequest\n")
        source = self._script("interaction", "services", "use.gd", body)
        return source, target

    def test_allowed_public_class_name_and_path(self) -> None:
        _, target = self._pair('extends RefCounted\nconst Payload = preload("res://content/domains/combat/contracts/damage_request.gd")\nvar request: DamageRequest\n')
        self._public("interaction", "combat", "DamageRequest", target)
        self.assertEqual([], self._check())

    def test_forbidden_internal_path_and_class_name_without_preload(self) -> None:
        _, target = self._pair('extends RefCounted\nvar request: DamageRequest\n')
        self.assertTrue(any("undeclared-public-edge" in error for error in self._check()))
        self._script("interaction", "services", "use.gd", 'extends RefCounted\nconst Private = preload("res://content/domains/combat/contracts/damage_request.gd")\n')
        self.assertTrue(any("undeclared-public-edge" in error for error in self._check()))

    def test_comments_and_diagnostic_strings_are_not_imports_or_symbols(self) -> None:
        self._pair('extends RefCounted\n# DamageRequest preload("res://content/domains/combat/contracts/damage_request.gd")\nconst MESSAGE = "DamageRequest"\nconst PATH_MESSAGE = "res://content/domains/combat/contracts/damage_request.gd"\nconst EXAMPLE = \'load("res://content/domains/combat/contracts/damage_request.gd")\'\n')
        self.assertEqual([], self._check())

    def test_constant_actual_load_is_checked(self) -> None:
        self._pair('extends RefCounted\nconst PATH: String = "res://content/domains/combat/contracts/damage_request.gd"\nfunc read() -> void:\n\tvar script: Script = load(PATH)\n')
        self.assertTrue(any("undeclared-public-edge" in error for error in self._check()))

    def test_shared_cannot_import_domain_even_with_public_edge(self) -> None:
        target = self._script("combat", "contracts", "damage_request.gd", "extends RefCounted\nclass_name DamageRequest\n")
        self._script("shared", "rules", "bad.gd", "extends RefCounted\nvar request: DamageRequest\n")
        self._public("shared", "combat", "DamageRequest", target)
        self.assertTrue(any("shared imports no domain" in error for error in self._check()))

    def test_domain_cannot_import_global_ui_even_with_public_edge(self) -> None:
        target = self._script("global", "ui", "panel.gd", "extends Control\nclass_name ForeignPanel\n")
        self._script("combat", "services", "bad.gd", "extends RefCounted\nvar panel: ForeignPanel\n")
        self._public("combat", "global", "ForeignPanel", target)
        self.assertTrue(any("global UI/composition" in error for error in self._check()))

    def test_domain_cannot_construct_global_ui_asset_without_class_reference(self) -> None:
        folder = self.root / "content/ui"
        folder.mkdir(parents=True)
        (folder / "panel.tscn").write_text("[gd_scene format=3]", encoding="utf-8")
        self._script("combat", "services", "bad.gd", 'extends RefCounted\nconst Panel = preload("res://content/ui/panel.tscn")\n')
        self.assertTrue(any("global UI/composition" in error for error in self._check()))

    def test_public_symbol_does_not_authorize_persistence_edge(self) -> None:
        target = self._script("persistence", "contracts", "save.gd", "extends RefCounted\nclass_name SaveResult\n")
        self._script("combat", "services", "bad.gd", "extends RefCounted\nvar result: SaveResult\n")
        self._public("combat", "persistence", "SaveResult", target)
        self.assertTrue(any("cannot import persistence" in error for error in self._check()))

    def test_unknown_target_path_and_mismatched_public_target_fail(self) -> None:
        self._script("combat", "services", "bad.gd", 'extends RefCounted\nconst Missing = preload("res://content/domains/interaction/contracts/missing.gd")\n')
        self.assertTrue(any("unknown imported script target" in error for error in self._check()))
        self._public("combat", "interaction", "UnknownPublic", "content/domains/interaction/contracts/missing.gd")
        self.assertTrue(any("Unknown/mismatched public target" in error for error in self._check()))

    def test_actual_public_implementation_cycle_fails(self) -> None:
        left = self._script("combat", "services", "left.gd", "extends RefCounted\nclass_name LeftService\nstatic func act() -> void:\n\tRightService.act()\n")
        right = self._script("interaction", "services", "right.gd", "extends RefCounted\nclass_name RightService\nstatic func act() -> void:\n\tLeftService.act()\n")
        self._public("combat", "interaction", "RightService", right, ["act"])
        self._public("interaction", "combat", "LeftService", left, ["act"])
        self.assertTrue(any("Actual implementation cycle" in error for error in self._check()))

    def test_reciprocal_coarse_leaf_data_references_pass(self) -> None:
        left = self._script("combat", "contracts", "left.gd", "extends RefCounted\nclass_name LeftRecord\nvar partner: RightRecord\n")
        right = self._script("interaction", "contracts", "right.gd", "extends RefCounted\nclass_name RightRecord\nvar partner: LeftRecord\n")
        self._public("combat", "interaction", "RightRecord", right)
        self._public("interaction", "combat", "LeftRecord", left)
        self.assertEqual([], self._check())

    def test_private_static_alias_operation_is_not_exported_by_public_class(self) -> None:
        target = self._script("combat", "services", "api.gd", "extends RefCounted\nclass_name PublicApi\nstatic func _private() -> void:\n\tpass\n")
        self._script("interaction", "services", "bad.gd", 'extends RefCounted\nconst Api = preload("res://content/domains/combat/services/api.gd")\nfunc apply() -> void:\n\tApi._private()\n')
        self._public("interaction", "combat", "PublicApi", target)
        self.assertTrue(any("private-api" in error for error in self._check()))

    def test_public_method_needs_declared_operation_and_access_right(self) -> None:
        target = self._script("combat", "services", "api.gd", "extends RefCounted\nclass_name PublicApi\nstatic func commit() -> void:\n\tpass\n")
        self._script("interaction", "services", "use.gd", "extends RefCounted\nfunc apply() -> void:\n\tPublicApi.commit()\n")
        self._public("interaction", "combat", "PublicApi", target)
        self.assertTrue(any("unauthorized-operation" in error for error in self._check()))
        self.edges[0]["public_methods"] = ["commit"]
        self.edges[0]["method_rights"] = {"commit": "request"}
        self.edges[0]["rights"] = ["read"]
        self.assertTrue(any("unauthorized-operation" in error for error in self._check()))
        self.edges[0]["rights"].append("request")
        self.assertEqual([], self._check())

    def test_exact_exemption_expires_and_cannot_hide_new_edge(self) -> None:
        self._pair("extends RefCounted\nvar request: DamageRequest\n")
        tasks = self.root / "agent_tasks/refactoring_v2"
        tasks.mkdir(parents=True)
        task = tasks / "30_owner.md"
        task.write_text("Status: **PLANNED**", encoding="utf-8")
        self._metadata()
        self.assertEqual([], capture_baseline(self.root))
        self.assertEqual([], self._check())
        self._script("interaction", "services", "new.gd", "extends RefCounted\nvar request: DamageRequest\n")
        self.assertTrue(any("new.gd: undeclared-public-edge" in error for error in self._check()))
        task.write_text("Status: **DONE**", encoding="utf-8")
        self.assertTrue(any("Expired legacy exemption" in error for error in self._check()))
        self.assertTrue(any("empty legacy baseline" in error for error in self._check(strict=True)))

    def test_typed_instance_private_operation_is_not_a_public_contract(self) -> None:
        target = self._script("combat", "services", "api.gd", "extends RefCounted\nclass_name PublicApi\nfunc _private() -> void:\n\tpass\n")
        self._script("interaction", "services", "bad.gd", "extends RefCounted\nfunc apply(api: PublicApi) -> void:\n\tapi._private()\n")
        self._public("interaction", "combat", "PublicApi", target)
        self.assertTrue(any("private-api" in error for error in self._check()))

    def test_typed_instance_api_cycle_fails(self) -> None:
        left = self._script("combat", "services", "left.gd", "extends RefCounted\nclass_name LeftService\nfunc act(peer: RightService) -> void:\n\tpeer.act(self)\n")
        right = self._script("interaction", "services", "right.gd", "extends RefCounted\nclass_name RightService\nfunc act(peer: LeftService) -> void:\n\tpeer.act(self)\n")
        self._public("combat", "interaction", "RightService", right)
        self._public("interaction", "combat", "LeftService", left)
        for edge in self.edges:
            edge["public_instance_methods"] = ["act"]
            edge["method_rights"] = {"act": "request"}
        self.assertTrue(any("Actual implementation cycle" in error for error in self._check()))

    def test_frozen_baseline_cannot_be_recaptured_to_hide_added_debt(self) -> None:
        self._pair("extends RefCounted\nvar request: DamageRequest\n")
        self._metadata()
        self.assertEqual([], capture_baseline(self.root))
        self._script("interaction", "services", "new.gd", "extends RefCounted\nvar request: DamageRequest\n")
        self.assertTrue(any("already frozen" in error for error in capture_baseline(self.root)))

    def test_resolved_cycle_exemption_is_stale_even_when_the_old_edge_remains(self) -> None:
        left = self._script("combat", "services", "left.gd", "extends RefCounted\nclass_name LeftService\nstatic func act() -> void:\n\tRightService.act()\n")
        right = self._script("interaction", "services", "right.gd", "extends RefCounted\nclass_name RightService\nstatic func act() -> void:\n\tLeftService.act()\n")
        self._public("combat", "interaction", "RightService", right, ["act"])
        self._public("interaction", "combat", "LeftService", left, ["act"])
        tasks = self.root / "agent_tasks/refactoring_v2"
        tasks.mkdir(parents=True)
        (tasks / "30_owner.md").write_text("Status: **PLANNED**", encoding="utf-8")
        self._metadata()
        self.assertEqual([], capture_baseline(self.root))
        self.assertEqual([], self._check())
        self._script("interaction", "services", "right.gd", "extends RefCounted\nclass_name RightService\nstatic func act() -> void:\n\tpass\n")
        self.assertTrue(any("Stale/mismatched" in error for error in self._check()))


if __name__ == "__main__":
    unittest.main()
