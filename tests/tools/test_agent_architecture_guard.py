"""Offline regressions for local new-change architecture guard (GECS aware)."""
from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
import sys

MODULE = Path(__file__).resolve().parents[2] / "utils/validate_agent_changes.py"
SPEC = importlib.util.spec_from_file_location("pvz_arch_guard", MODULE)
assert SPEC and SPEC.loader
module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = module
SPEC.loader.exec_module(module)


class ArchitectureGuardTests(unittest.TestCase):
    def test_gameplay_script_generation_fails(self) -> None:
        source = 'extends Node\nvar generator = GDScript.new()\n'
        results = module.inspect_file("content/domains/npc/services/writer.gd", source, None)
        self.assertTrue(any(f.severity == "ERROR" for f in results))

    def test_runtime_authored_file_write_fails(self) -> None:
        source = 'extends Node\nvar output = FileAccess.open("res://content/ui/menu.tscn", FileAccess.WRITE)\n'
        results = module.inspect_file("content/ui/writer.gd", source, None)
        self.assertTrue(any(f.severity == "ERROR" and "writes" in f.reason for f in results))

    def test_old_large_system_is_not_penalized_by_size(self) -> None:
        source = "extends System\n" + "# existing responsibility\n" * 800
        self.assertEqual([], module.inspect_file("content/domains/npc/systems/s_intent.gd", source, source))

    def test_new_large_system_requires_review_not_forced_split(self) -> None:
        source = "extends System\n" + "# real logic\n" * 705
        results = module.inspect_file("content/domains/npc/systems/s_big.gd", source, None)
        self.assertEqual(["REVIEW"], [f.severity for f in results])

    def test_scripted_menu_layout_requires_review(self) -> None:
        source = "extends CanvasLayer\n" + "var control = Label.new()\n" * 6
        results = module.inspect_file("content/ui/new_menu.gd", source, None)
        self.assertTrue(any("UI layout" in f.reason for f in results))

    def test_comment_examples_are_not_executable_generators(self) -> None:
        text = "extends Node\n# Do not run GDScript.new() in production\n"
        self.assertEqual([], module.inspect_file("content/ui/help.gd", text, None))

    def test_legitimate_dynamic_card_is_not_blocked(self) -> None:
        source = "extends Control\nvar row = Label.new()\n"
        self.assertEqual([], module.inspect_file("content/ui/dynamic_card.gd", source, None))

    def test_empty_authored_root_requires_review(self) -> None:
        tscn = ('[gd_scene load_steps=2 format=3]\n'
                '[ext_resource type="Script" path="res://content/ui/new_menu.gd" id="1"]\n'
                '[node name="Menu" type="Control"]\nscript = ExtResource("1")\n')
        results = module.inspect_file("content/ui/new_menu.tscn", tscn, None)
        self.assertTrue(any("root" in f.reason for f in results))
        self.assertEqual([], module.inspect_file("content/ui/new_menu.tscn", tscn + '[node name="Title" type="Label" parent="."]\n', None))

    def test_existing_import_pipeline_is_exempt(self) -> None:
        code = 'extends EditorScript\nResourceSaver.save(a, "res://models/saved.tscn")\n'
        self.assertEqual([], module.inspect_file("utils/gltf_import_split_script.gd", code, code))

    def test_editor_snapshot_is_not_a_gameplay_scene_generator(self) -> None:
        code = ('@tool\nextends EditorInspectorPlugin\nvar snapshot = PackedScene.new()\n'
                'ResourceSaver.save(snapshot, "res://.artifacts/snapshot.tscn")\n')
        self.assertEqual([], module.inspect_file(
            "content/editor/entity_authoring/inspector.gd", code, None))
        self.assertTrue(any(f.severity == "ERROR" for f in module.inspect_file(
            "content/domains/npc/services/generator.gd", code, None)))

    def test_new_tool_generator_needs_review(self) -> None:
        code = 'from pathlib import Path\nPath("whole_game.gd").write_text("extends Node")\n'
        found = module.inspect_file("utils/one_click_game.py", code, None)
        self.assertTrue(any(f.severity == "REVIEW" for f in found))

    def test_gdscript_reader_writing_json_is_not_a_scene_generator(self) -> None:
        code = ('extends SceneTree\nvar rules = load("res://content/rules.gd")\n'
                'var output = FileAccess.open("res://tests/artifacts/result.json", FileAccess.WRITE)\n')
        self.assertEqual([], module.inspect_file("utils/preview.gd", code, None))
        scene_writer = code.replace("result.json", "result.tscn")
        self.assertTrue(any(f.severity == "REVIEW" for f in module.inspect_file(
            "utils/preview.gd", scene_writer, None)))

    def test_rename_aware_git_baseline_and_staged(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            def git(*cmd):
                subprocess.run(["git", *cmd], cwd=root, check=True, capture_output=True)
            git("init", "-q")
            git("config", "user.email", "test@example.invalid")
            git("config", "user.name", "Test")
            path = root / "content/domains/npc/systems/s_normal.gd"
            path.parent.mkdir(parents=True)
            original = "extends System\n" + "# existing\n" * 720
            path.write_text(original)
            git("add", ".")
            git("commit", "-qm", "initial")
            destination = path.with_name("s_renamed.gd")
            path.rename(destination)
            git("add", "-A")
            count, findings = module.scan(root, staged=True)
            self.assertEqual(1, count)
            self.assertEqual([], findings)
            destination.write_text(original + "var x = GDScript.new()\n")
            git("add", "-A")
            count, findings = module.scan(root, staged=True)
            self.assertTrue(any(f.severity == "ERROR" for f in findings))

    def test_report_only_is_never_a_pass_message(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.email", "test@example.invalid"], cwd=root, check=True)
            subprocess.run(["git", "config", "user.name", "Test"], cwd=root, check=True)
            (root / "README.md").write_text("test\n")
            subprocess.run(["git", "add", "."], cwd=root, check=True)
            subprocess.run(["git", "commit", "-qm", "initial"], cwd=root, check=True)
            self.assertEqual(0, module.main(["--root", str(root), "--report-only"]))


if __name__ == "__main__":
    unittest.main()
