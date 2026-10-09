"""Offline contract tests for the PVZ parallel review pilot (no model/Godot calls)."""
from __future__ import annotations

import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


class ParallelReviewPolicyTests(unittest.TestCase):
    def test_one_child_parallel_with_main(self) -> None:
        config = tomllib.loads(read(".codex/config.toml"))
        self.assertTrue(config["agents"]["enabled"])
        self.assertGreaterEqual(config["agents"]["max_concurrent_threads_per_session"], 1)
        self.assertLessEqual(config["agents"]["max_concurrent_threads_per_session"], 2)
        self.assertIn("reviewer", config["agents"])
        self.assertIn("validator", config["agents"])

    def test_instructions_within_always_loaded_budget(self) -> None:
        config = tomllib.loads(read(".codex/config.toml"))
        size = len(read("AGENTS.md").encode("utf-8"))
        self.assertLessEqual(size, config["project_doc_max_bytes"])

    def test_reviewer_permissions_are_read_only_and_nonrecursive(self) -> None:
        reviewer = tomllib.loads(read(".codex/agents/reviewer.toml"))
        self.assertEqual("read-only", reviewer["sandbox_mode"])
        self.assertEqual("never", reviewer["approval_policy"])
        self.assertEqual(False, reviewer["agents"]["enabled"])
        self.assertIsInstance(reviewer["developer_instructions"], str)

    def test_reviewer_uses_pinned_snapshot_not_live_worktree(self) -> None:
        instructions = tomllib.loads(read(".codex/agents/reviewer.toml"))["developer_instructions"]
        for required in ("BASE_SHA", "TARGET_SHA", "git diff", "git show",
                         "Never git checkout", "NOT_RUN", "P0/P1/P2/P3"):
            with self.subTest(required=required):
                self.assertIn(required, instructions)
        self.assertIn("Do not create tasks", instructions)

    def test_main_owns_triage_and_blocks_unreviewed_milestone(self) -> None:
        policy = read("AGENTS.md")
        for token in ("Main is the only code writer", "REVIEW_PENDING",
                      "P0/P1/P2", "review-orchestration", "independent work"):
            with self.subTest(token=token):
                self.assertIn(token, policy)

    def test_skill_metadata_and_repair_limit(self) -> None:
        skill = read(".agents/skills/review-orchestration/SKILL.md")
        self.assertTrue(skill.startswith("---\nname: review-orchestration\n"))
        self.assertIn("description:", skill.split("---", 2)[1])
        self.assertIn("two targeted repair/re-review cycles", skill)
        self.assertIn("not PASS", skill)

    def test_review_queue_remains_in_owning_task(self) -> None:
        task_policy = read("agent_tasks/README.md")
        guide = read("docs/parallel_review_workflow.md")
        self.assertIn("same existing task", task_policy)
        self.assertIn("RV-001", guide)
        self.assertIn("REVIEW_PENDING", guide)
        self.assertIn("NOT_MEASURED", guide)

    def test_copy_ready_prompts_are_present(self) -> None:
        cheatsheet = read("docs/ai_prompt_cheatsheet.md")
        for label in ("Feature с параллельным review", "Рефакторинг большой подсистемы",
                      "Безопасный маленький Fix", "Возобновление",
                      "Отдельный независимый review", "Сравнение последовательного"):
            with self.subTest(label=label):
                self.assertIn(label, cheatsheet)
        self.assertIn("parallel_review_workflow.md", read("docs/README.md"))

    def test_validator_is_sequential_to_reviewer(self) -> None:
        validator = tomllib.loads(read(".codex/agents/validator.toml"))
        self.assertIn("do not run concurrently with reviewer",
                      validator["developer_instructions"])


if __name__ == "__main__":
    unittest.main()
