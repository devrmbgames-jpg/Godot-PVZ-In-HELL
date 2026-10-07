"""Regression fixtures for broken planning graphs and false readiness."""

from __future__ import annotations

import sys
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "utils"))

from validate_refactoring_preflight import (
    PREFLIGHT, SCORE_CATEGORIES, validate, validate_git_scope, validate_phase0_paths,
)


class RefactoringPreflightTest(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.task_root = self.root / "agent_tasks/refactoring_v2"
        self.task_root.mkdir(parents=True)
        (self.root / "docs").mkdir()
        (self.root / "docs/project_core_architecture_proposal.md").write_text(
            "Status: **PREFLIGHT_TARGET_APPROVED — IMPLEMENTATION_PENDING**\n", encoding="utf-8"
        )
        self.names = [*PREFLIGHT, "01_architecture_contract.md"]
        for index, name in enumerate(self.names):
            dependency = (
                f"[{self.names[index - 1]}]({self.names[index - 1]})"
                if index
                else "none"
            )
            status = "DONE" if index < 5 else "PLANNED"
            content = f"Status: **{status}**\n\nЗависимости: {dependency}\n\n## Goal\n"
            if index == 4:
                content += "Result: **READY_FOR_IMPLEMENTATION**\nBlockers: NONE\n"
                content += "\n".join(
                    f"| {category} | 8/10 | Defined gate |" for category in SCORE_CATEGORIES
                )
            (self.task_root / name).write_text(content, encoding="utf-8")
        self.roadmap = self.task_root / "README.md"
        self.roadmap.write_text(
            "Status: **READY_FOR_IMPLEMENTATION**\nNext task: `01_architecture_contract.md`\n\n"
            + "\n".join(
                f"{index}. [{name}]({name})"
                for index, name in enumerate(self.names, start=1)
            ),
            encoding="utf-8",
        )

    def _append(self, path: Path, content: str) -> None:
        path.write_text(path.read_text(encoding="utf-8") + content, encoding="utf-8")

    def _replace(self, path: Path, old: str, new: str) -> None:
        path.write_text(path.read_text(encoding="utf-8").replace(old, new), encoding="utf-8")

    def test_valid_completed_gate(self) -> None:
        self.assertEqual([], validate(self.root, require_gate=True))

    def test_duplicate_and_missing_tasks(self) -> None:
        self._append(self.roadmap, f"\n7. [duplicate]({PREFLIGHT[0]})\n")
        missing = self.task_root / "02_new_task.md"
        missing.write_text("Зависимости: 01_architecture_contract.md\n", encoding="utf-8")
        errors = validate(self.root)
        self.assertTrue(any("duplicate" in error for error in errors))
        self.assertTrue(any("omits 02_new_task.md" in error for error in errors))

    def test_backward_prerequisite_and_cycle(self) -> None:
        first = self.task_root / PREFLIGHT[0]
        first.write_text(f"Зависимости: {PREFLIGHT[1]}\n", encoding="utf-8")
        errors = validate(self.root)
        self.assertTrue(any("does not appear earlier" in error for error in errors))
        self.assertTrue(any("cycle" in error for error in errors))

    def test_unknown_prerequisite(self) -> None:
        task = self.task_root / self.names[-1]
        task.write_text("Зависимости: 99_missing.md\n", encoding="utf-8")
        self.assertTrue(any("unknown prerequisite" in error for error in validate(self.root)))

    def test_broken_link_and_encoding(self) -> None:
        self._append(self.task_root / PREFLIGHT[0], "\n[Missing](../../missing.md)\n???\n")
        errors = validate(self.root)
        self.assertTrue(any("broken local link" in error for error in errors))
        self.assertTrue(any("encoding" in error for error in errors))

    def test_future_task_started_and_gate_mismatch(self) -> None:
        task = self.task_root / self.names[-1]
        task.write_text(
            "Status: **DONE**\n\nЗависимости: " + PREFLIGHT[-1], encoding="utf-8"
        )
        self.roadmap.write_text(
            self.roadmap.read_text(encoding="utf-8").replace(
                "Status: **READY_FOR_IMPLEMENTATION**", "Status: **PLANNED**"
            ),
            encoding="utf-8",
        )
        errors = validate(self.root, require_gate=True)
        self.assertTrue(any("started during preflight" in error for error in errors))
        self.assertTrue(any("does not match" in error for error in errors))

    def test_link_outside_repository_is_rejected(self) -> None:
        self._append(self.task_root / PREFLIGHT[0], "\n[Outside](../../../outside.md)\n")
        self.assertTrue(any("escapes repository" in error for error in validate(self.root)))

    def test_missing_final_result(self) -> None:
        task = self.task_root / PREFLIGHT[-1]
        task.write_text(
            task.read_text(encoding="utf-8").replace(
                "Result: **READY_FOR_IMPLEMENTATION**", ""
            ),
            encoding="utf-8",
        )
        self.assertTrue(any("no explicit final Result" in error for error in validate(self.root, True)))

    def test_incomplete_preflight_cannot_claim_gate(self) -> None:
        task = self.task_root / PREFLIGHT[2]
        task.write_text(
            task.read_text(encoding="utf-8").replace("**DONE**", "**PLANNED**"),
            encoding="utf-8",
        )
        self.assertTrue(any("not DONE" in error for error in validate(self.root, True)))

    def test_not_ready_is_a_valid_completed_audit(self) -> None:
        for path in (self.task_root / PREFLIGHT[-1], self.roadmap):
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "**READY_FOR_IMPLEMENTATION**", "**NOT_READY_FOR_IMPLEMENTATION**"
                ),
                encoding="utf-8",
            )
        gate = self.task_root / PREFLIGHT[-1]
        self._replace(gate, "Blockers: NONE", "Blockers: Unresolved ownership")
        self._replace(self.roadmap, "Next task: `01_architecture_contract.md`",
                      "Next planning action: Resolve ownership")
        (self.root / "docs/project_core_architecture_proposal.md").write_text(
            "Status: **PREFLIGHT_NOT_READY — IMPLEMENTATION_BLOCKED**\n", encoding="utf-8"
        )
        self.assertEqual([], validate(self.root, require_gate=True))

    def test_wrong_next_task_and_proposal_status_fail(self) -> None:
        self._replace(self.roadmap, "Next task: `01_architecture_contract.md`",
                      "Next task: `02_execution_ownership_rules.md`")
        (self.root / "docs/project_core_architecture_proposal.md").write_text(
            "Status: **PLANNED**\n", encoding="utf-8"
        )
        errors = validate(self.root, True)
        self.assertTrue(any("sole next task" in error for error in errors))
        self.assertTrue(any("proposal Status" in error for error in errors))

    def test_duplicate_status_and_verdict_fail(self) -> None:
        self._append(self.roadmap, "\nStatus: **NOT_READY_FOR_IMPLEMENTATION**\n")
        self._append(self.task_root / PREFLIGHT[-1], "\nResult: **NOT_READY_FOR_IMPLEMENTATION**\n")
        errors = validate(self.root, True)
        self.assertTrue(any("exactly one Status" in error for error in errors))
        self.assertTrue(any("explicit final Result" in error for error in errors))

    def test_readiness_requires_all_six_valid_scores(self) -> None:
        gate = self.task_root / PREFLIGHT[-1]
        self._replace(gate, "| Designer UX | 8/10 | Defined gate |",
                      "| Designer UX | 11/10 | - |")
        self.assertTrue(any("scorecard" in error for error in validate(self.root, True)))

    def test_low_score_requires_explanation(self) -> None:
        gate = self.task_root / PREFLIGHT[-1]
        self._replace(gate, "| Designer UX | 8/10 | Defined gate |", "| Designer UX | 7/10 | - |")
        self.assertTrue(any("below 8" in error for error in validate(self.root, True)))

    def test_ready_cannot_hide_blockers(self) -> None:
        gate = self.task_root / PREFLIGHT[-1]
        self._replace(gate, "Blockers: NONE", "Blockers: Unresolved ownership")
        self.assertTrue(any("Blockers: NONE" in error for error in validate(self.root, True)))

    def test_allowed_planning_scope(self) -> None:
        self.assertEqual([], validate_phase0_paths([
            "agent_tasks/refactoring_v2/README.md", "docs/project_core_architecture_proposal.md",
            "content/ARCHITECTURE.md", ".agents/skills/save-systems/SKILL.md", "AGENTS.md",
            "utils/validate_refactoring_preflight.py", "tests/tools/test_validate_refactoring_preflight.py",
        ]))

    def test_runtime_addon_config_and_path_escape_scope_fail(self) -> None:
        paths = [
            "content/systems/s_ai.gd", "content/scenes/level.tscn", "addons/gecs/ecs/world.gd",
            ".codex/config.toml", "tests/gut/test_ai.gd", "../docs/architecture.md",
            "agent_tasks/refactoring_v2/../escape.md",
        ]
        self.assertEqual(len(paths), len(validate_phase0_paths(paths)))

    def test_git_commit_and_staged_scope_use_changed_paths(self) -> None:
        with patch("validate_refactoring_preflight.subprocess.run") as run:
            run.return_value = subprocess.CompletedProcess([], 0, b"content/systems/s_ai.gd\0", b"")
            self.assertTrue(validate_git_scope(self.root, "1234567"))
            self.assertIn("1234567", run.call_args.args[0])
            run.return_value = subprocess.CompletedProcess([], 0, b"AGENTS.md\0", b"")
            self.assertEqual([], validate_git_scope(self.root))
            self.assertIn("--cached", run.call_args.args[0])
            self.assertNotIn("shell", run.call_args.kwargs)

    def test_git_failure_and_invalid_commit_fail_closed(self) -> None:
        self.assertTrue(validate_git_scope(self.root, "--all"))
        with patch("validate_refactoring_preflight.subprocess.run") as run:
            run.return_value = subprocess.CompletedProcess([], 128, b"", b"unknown commit")
            self.assertTrue(validate_git_scope(self.root, "1234567"))
            run.side_effect = subprocess.TimeoutExpired("git", 20)
            self.assertTrue(validate_git_scope(self.root))

    def test_not_ready_without_concrete_blockers_and_next_action_fails(self) -> None:
        for path in (self.task_root / PREFLIGHT[-1], self.roadmap):
            self._replace(path, "**READY_FOR_IMPLEMENTATION**", "**NOT_READY_FOR_IMPLEMENTATION**")
        errors = validate(self.root, True)
        self.assertTrue(any("next planning action" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
