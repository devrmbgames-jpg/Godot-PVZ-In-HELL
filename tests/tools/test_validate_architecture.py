"""Behavioral fixtures for architecture discovery, debt budgets and false positives."""

from __future__ import annotations

import tempfile
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "utils"))
from validate_architecture import scan, validate


class ArchitectureValidationTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def write(self, path: str, text: str) -> Path:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text, encoding="utf-8")
        return destination

    def allowance(self, findings: list) -> dict:
        return {"version": 1, "entries": [
            {"rule": f.rule, "owner": f.owner, "method": f.method, "target": f.target,
             "count": 1, "reason": "Legacy scheduled step", "task": "17_combat.md",
             "removal_gate": "26/27"} for f in findings
        ]}

    def test_new_service_step_fails_and_budgeted_legacy_passes(self) -> None:
        self.write("content/services/a.gd", "class_name LegacyService\nstatic func tick():\n\tpass\n")
        findings = scan(self.root)
        self.assertEqual(1, len(findings))
        self.assertTrue(validate(findings, {"entries": []}))
        self.assertEqual([], validate(findings, self.allowance(findings)))

    def test_direct_and_deferred_forwarding_are_detected(self) -> None:
        self.write("content/systems/a.gd", "extends System\nclass_name S_A\nfunc process():\n\tFooService.tick()\n\tcmd.add_custom(BarService.update.bind(1))\n")
        self.assertEqual({"FooService.tick", "BarService.update"}, {f.target for f in scan(self.root)})

    def test_additional_call_cannot_hide_in_old_allowance(self) -> None:
        path = self.write("content/systems/a.gd", "extends System\nclass_name S_A\nfunc process():\n\tFooService.tick()\n")
        baseline = self.allowance(scan(self.root))
        path.write_text(path.read_text() + "\tFooService.tick()\n", encoding="utf-8")
        self.assertTrue(validate(scan(self.root), baseline))

    def test_custom_system_base_cannot_bypass_role_or_symbol_discovery(self) -> None:
        self.write("content/domains/npc/systems/a.gd", "extends CustomSystem\nfunc process():\n\tFooService.tick()\n")
        self.write("logic/b.gd", "extends CustomSystem\nclass_name S_B\nfunc process():\n\tBarService.tick()\n")
        self.assertEqual(2, len(scan(self.root)))

    def test_symbol_baseline_survives_move_and_other_paths_are_discovered(self) -> None:
        old = self.write("content/services/a.gd", "class_name LegacyService\nstatic func tick():\n\tpass\n")
        baseline = self.allowance(scan(self.root))
        target = self.root / "content/domains/combat/services/a.gd"
        target.parent.mkdir(parents=True)
        old.rename(target)
        self.assertEqual([], validate(scan(self.root), baseline))
        self.write("tools/rogue.gd", "class_name RogueService\nstatic func process():\n\tpass\n")
        self.assertTrue(validate(scan(self.root), baseline))

    def test_query_only_in_step_body_is_detected(self) -> None:
        self.write("content/services/a.gd", "class_name FooService\nstatic func tick():\n\tECS.world.query.execute()\nstatic func lookup():\n\tECS.world.query.execute()\n")
        self.assertEqual(["service-step", "service-step-query"], [f.rule for f in scan(self.root)])

    def test_comments_strings_multiline_and_escaped_quotes_are_ignored(self) -> None:
        self.write("content/systems/a.gd", '''extends System
class_name S_A
func process():
\t# FooService.tick()
\tvar example = "FooService.tick()"
\tvar long_example = """FooService.tick()
static func tick():
ECS.world.query.execute()
"""
\tvar escaped = 'It\\'s FooService.tick()'
''')
        self.assertEqual([], scan(self.root))

    def test_solver_explicit_commands_tests_and_addons_are_allowed(self) -> None:
        self.write("content/services/solver.gd", "class_name MotionSolver\nstatic func integrate_forces():\n\tpass\n")
        self.write("content/services/wallet.gd", "class_name WalletService\nstatic func submit():\n\tECS.world.query.execute()\n")
        self.write("tests/a.gd", "class_name TestService\nstatic func tick():\n\tpass\n")
        self.write("addons/a.gd", "class_name AddonService\nstatic func tick():\n\tpass\n")
        self.assertEqual([], scan(self.root))

    def test_removed_debt_rejects_stale_allowance(self) -> None:
        path = self.write("content/services/a.gd", "class_name FooService\nstatic func tick():\n\tpass\n")
        baseline = self.allowance(scan(self.root))
        path.unlink()
        self.assertTrue(validate(scan(self.root), baseline))

    def test_strict_gate_rejects_legacy_and_passes_empty_model(self) -> None:
        self.write("content/services/a.gd", "class_name FooService\nstatic func tick():\n\tpass\n")
        findings = scan(self.root)
        self.assertTrue(validate(findings, self.allowance(findings), strict=True))
        self.assertEqual([], validate([], {"entries": []}, strict=True))

    def test_reason_task_removal_gate_and_duplicate_budgets_are_required(self) -> None:
        self.write("content/services/a.gd", "class_name FooService\nstatic func tick():\n\tpass\n")
        findings = scan(self.root)
        for field in ("reason", "task", "removal_gate"):
            baseline = self.allowance(findings)
            baseline["entries"][0].pop(field)
            self.assertTrue(validate(findings, baseline))
        baseline = self.allowance(findings)
        baseline["entries"] *= 2
        self.assertTrue(validate(findings, baseline))

    def test_nested_untracked_and_ignored_directories_do_not_trigger(self) -> None:
        self.write(".godot/a.gd", "class_name CacheService\nstatic func tick():\n\tpass\n")
        self.write("scratch/.gdignore", "")
        self.write("scratch/a.gd", "class_name ScratchService\nstatic func tick():\n\tpass\n")
        self.assertEqual([], scan(self.root))

    def test_typed_private_node_binding_is_rejected_before_callback_guard(self) -> None:
        self.write("content/systems/a.gd", "extends System\nclass_name S_A\nfunc process():\n\tcmd.add_custom(_apply.bind(subject))\nfunc _apply(subject: Entity) -> void:\n\tif is_instance_valid(subject):\n\t\tpass\n")
        self.assertEqual(["queued-typed-node"], [f.rule for f in scan(self.root)])

    def test_external_callback_resolves_custom_native_node_type(self) -> None:
        self.write("content/entities/a.gd", "extends RigidBody3D\nclass_name E_Parcel\n")
        self.write("content/services/a.gd", "class_name ParcelService\nstatic func release(parcel: E_Parcel) -> void:\n\tpass\n")
        self.write("content/observers/a.gd", "extends Observer\nclass_name O_A\nfunc each():\n\tcmd.add_custom(ParcelService.release.bind(parcel))\n")
        self.assertEqual(["queued-typed-node"], [f.rule for f in scan(self.root)])

    def test_resource_payload_weak_reference_and_native_signal_are_not_buffer_node_bindings(self) -> None:
        self.write("content/systems/a.gd", "extends System\nclass_name S_A\nfunc process():\n\tcmd.add_custom(_apply.bind(weakref(subject), state))\n\tbody.body_exited.connect(_on_exit.bind(body))\nfunc _apply(subject: WeakRef, state: Resource) -> void:\n\tpass\nfunc _on_exit(other: Node, body: PhysicsBody3D) -> void:\n\tpass\n")
        self.assertEqual([], scan(self.root))

    def test_pinned_structural_closure_and_bound_node_method_are_rejected(self) -> None:
        self.write("content/observers/a.gd", "extends Observer\nclass_name O_A\nfunc each():\n\tcmd.remove_relationship(subject, binding)\n\tcmd.add_custom(subject.remove_relationship.bind(binding))\n")
        self.assertEqual({"queued-node-closure", "queued-typed-node"}, {f.rule for f in scan(self.root)})

    def test_system_imperative_calls_are_rejected_but_construction_is_allowed(self) -> None:
        self.write("content/systems/a.gd", "extends System\nclass_name S_A\nfunc process():\n\tS_B.advance(entity)\n\tS_B.new()\n")
        self.assertEqual(["S_B.advance"], [f.target for f in scan(self.root)])


if __name__ == "__main__":
    unittest.main()
