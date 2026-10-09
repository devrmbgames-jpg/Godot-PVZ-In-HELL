"""Offline tests ensuring always-loaded PVZ instructions stay concise."""
from __future__ import annotations

import re
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def installed_skills() -> list[Path]:
    return list((ROOT / ".agents/skills").glob("*" + "/SKILL.md"))


class AgentInstructionBudgetTests(unittest.TestCase):
    def test_root_is_small_and_below_codex_budget(self) -> None:
        size = len(read("AGENTS.md").encode("utf-8"))
        limit = tomllib.loads(read(".codex/config.toml"))["project_doc_max_bytes"]
        self.assertLessEqual(size, 8192)
        self.assertLessEqual(size, limit)

    def test_every_routed_skill_exists(self) -> None:
        names = set(re.findall(r"\.agents/skills/([a-z0-9.-]+)/SKILL\.md", read("AGENTS.md")))
        self.assertGreaterEqual(len(names), 8)
        for name in names:
            with self.subTest(name=name):
                self.assertTrue((ROOT / ".agents/skills" / name / "SKILL.md").is_file())

    def test_catalog_covers_all_installed_skills(self) -> None:
        catalog = read(".agents/skills/README.md")
        for path in installed_skills():
            with self.subTest(name=path.parent.name):
                self.assertIn("`" + path.parent.name + "`", catalog)

    def test_task_lifecycle_rules_are_not_duplicated(self) -> None:
        root = read("AGENTS.md")
        task = read("agent_tasks/README.md")
        self.assertIn("agent_tasks/README.md", root)
        self.assertNotIn("200 lines", root)
        self.assertIn("200 lines", task)
        self.assertIn("agent_tasks/completed/", task)

    def test_memory_policy_is_in_performance_skill(self) -> None:
        root = read("AGENTS.md")
        policy = read(".agents/skills/godot-performance/SKILL.md")
        self.assertIn("KNOWN_ENGINE_LIMITATION / DEFERRED", root)
        self.assertNotIn("50–100 times", root)
        self.assertIn("50–100 times", policy)
        self.assertIn("stable Godot 4.8+", policy)

    def test_scene_ownership_is_in_editor_skill(self) -> None:
        mcp = read(".agents/skills/godot-ai-mcp/SKILL.md")
        self.assertIn("Ignore External Changes", mcp)
        self.assertIn("start-godot.ps1", mcp)
        self.assertIn("editor-loaded", mcp)

    def test_parallel_review_contract_remains(self) -> None:
        root = read("AGENTS.md")
        for required in ("Main is the only code writer", "BASE_SHA..TARGET_SHA",
                         "REVIEW_PENDING", "independent work", "P0/P1/P2"):
            self.assertIn(required, root)
        self.assertIn("two targeted repair/re-review cycles",
                      read(".agents/skills/review-orchestration/SKILL.md"))

    def test_no_dangling_agenda_anchors_in_skills(self) -> None:
        for path in installed_skills():
            with self.subTest(path=path):
                content = path.read_text(encoding="utf-8")
                self.assertNotIn("AGENTS.md#validation-and-commits", content)
                self.assertNotIn("AGENTS.md#plan-goal-and-durable-task-state", content)

    def test_agent_capacity_and_review_policy_agree(self) -> None:
        config = tomllib.loads(read(".codex/config.toml"))
        limit = config["agents"]["max_concurrent_threads_per_session"]
        self.assertGreaterEqual(limit, 1)
        self.assertLessEqual(limit, 2)
        self.assertIn("один read-only Reviewer", read("docs/parallel_review_workflow.md"))

    def test_root_keeps_baseline_safety(self) -> None:
        root = read("AGENTS.md").lower()
        for token in ("master", "GitHub CLI", "addons/gecs", "GDScript", "Godot",
                      "validate_architecture.py"):
            self.assertIn(token.lower(), root)


if __name__ == "__main__":
    unittest.main()
