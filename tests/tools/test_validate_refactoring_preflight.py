"""Regression fixtures for broken planning graphs and false readiness."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "utils"))

from validate_refactoring_preflight import PREFLIGHT, validate


class RefactoringPreflightTest(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.task_root = self.root / "agent_tasks/refactoring_v2"
        self.task_root.mkdir(parents=True)
        (self.root / "docs").mkdir()
        (self.root / "docs/project_core_architecture_proposal.md").write_text(
            "# Target\n", encoding="utf-8"
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
                content += "Result: **READY_FOR_IMPLEMENTATION**\n"
            (self.task_root / name).write_text(content, encoding="utf-8")
        self.roadmap = self.task_root / "README.md"
        self.roadmap.write_text(
            "Status: **READY_FOR_IMPLEMENTATION**\n\n"
            + "\n".join(
                f"{index}. [{name}]({name})"
                for index, name in enumerate(self.names, start=1)
            ),
            encoding="utf-8",
        )

    def _append(self, path: Path, content: str) -> None:
        path.write_text(path.read_text(encoding="utf-8") + content, encoding="utf-8")

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
        self.assertEqual([], validate(self.root, require_gate=True))


if __name__ == "__main__":
    unittest.main()
