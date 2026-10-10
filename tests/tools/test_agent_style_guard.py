"""Offline tests for PVZ role-aware GDScript style gate; no external formatter required."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[2] / "utils/check_gdscript_format.py"
SPEC = importlib.util.spec_from_file_location("pvz_style", MODULE)
assert SPEC and SPEC.loader
style = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(style)


class StyleGuardTests(unittest.TestCase):
    def test_manifest_rejects_missing_duplicate_and_stale_scripts(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "content").mkdir()
            (root / "utils").mkdir()
            (root / "content/a.gd").write_text("extends Node\n", encoding="utf-8")
            tasks = {str(n): [] for n in range(61, 66)}
            tasks["61"] = ["content/a.gd"]
            manifest = root / "utils/gdscript_style_manifest.json"
            def write() -> None:
                manifest.write_text(json.dumps({"schema_version": 1, "tasks": tasks}),
                                    encoding="utf-8")
            write()
            self.assertEqual(["content/a.gd"], style.manifest_files(root, "61"))
            tasks["62"] = ["content/a.gd"]
            write()
            with self.assertRaises(ValueError):
                style.manifest_files(root, "61")
            tasks["62"] = []
            tasks["61"] = []
            write()
            with self.assertRaises(ValueError):
                style.manifest_files(root, "61")
            tasks["61"] = ["content/stale.gd"]
            write()
            with self.assertRaises(ValueError):
                style.manifest_files(root, "61")

    def test_full_scope_includes_owned_plugins_and_excludes_generated_vendor_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            paths = ("content/a.gd", "tests/gut/test_a.gd", "utils/a.gd",
                     "addons/pvz_ai_tools/a.gd", "addons/project_entity_traits/a.gd",
                     "addons/gecs/a.gd", ".godot/a.gd", ".artifacts/a.gd",
                     "tests/artifacts/generated_probe.gd")
            for name in paths:
                script = root / name
                script.parent.mkdir(parents=True, exist_ok=True)
                script.write_text("extends Node\n", encoding="utf-8")
            self.assertEqual(sorted(paths[:5]), style.project_files(root))

    def test_formatter_version_mismatch_is_not_accepted(self) -> None:
        response = SimpleNamespace(returncode=0, stdout="gdscript-formatter 0.25.0", stderr="")
        with patch.object(style.subprocess, "run", return_value=response):
            with self.assertRaises(RuntimeError):
                style.verify_formatter_version("formatter")

    def test_explicit_missing_path_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            self.assertEqual(2, style.main(["--root", temp, "--strict", "missing.gd"]))

    def test_absolute_vendor_paths_cannot_bypass_ownership_filter(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            vendor = Path(temp) / "addons/gecs/vendor.gd"
            vendor.parent.mkdir(parents=True)
            vendor.write_text("extends Node\n", encoding="utf-8")
            with patch.object(style, "inspect_file") as inspect:
                self.assertEqual(0, style.main(["--root", temp, "--strict", str(vendor)]))
            inspect.assert_not_called()

    def test_full_cli_cannot_pass_without_formatter(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "content/sample.gd"
            source.parent.mkdir()
            source.write_text("extends Node\n", encoding="utf-8")
            with patch.object(style, "formatter_binary", return_value=None):
                self.assertEqual(2, style.main(["--root", temp, "--all"]))

    def test_native_formatter_accepts_roles_rejects_bad_code_without_writes(self) -> None:
        binary = style.formatter_binary(MODULE.parents[1])
        if binary is None:
            self.skipTest("Pinned formatter not available")
        style.verify_formatter_version(binary)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            script = root / "fixture.gd"
            good = "class_name C_Test\nextends Node\n"
            script.write_text(good, encoding="utf-8", newline="\n")
            issues, missing = style.inspect_file(root, "fixture.gd", None, binary, True)
            self.assertEqual([], issues)
            self.assertFalse(missing)
            self.assertEqual(good, script.read_text(encoding="utf-8"))
            bad = "class_name C_bad\nextends Node\nfunc bad_function():\n  pass \n"
            script.write_text(bad, encoding="utf-8", newline="\n")
            issues, missing = style.inspect_file(root, "fixture.gd", None, binary, True)
            self.assertFalse(missing)
            self.assertTrue(any("invalid class_name" in issue for issue in issues))
            self.assertTrue(any("trailing whitespace" in issue for issue in issues))
            self.assertTrue(any("formatter check failed" in issue for issue in issues))
            self.assertEqual(bad, script.read_text(encoding="utf-8"))

    def test_roles_are_allowed_as_human_readable_contracts(self) -> None:
        for name in ("C_Health", "S_NpcIntent", "O_CustomerArrived", "R_OwnedBy",
                     "E_NpcCharacter", "DEF_NpcProfile", "ET_Customer", "UI_TerminalPanel",
                     "CustomerFlowService", "SettingsMenu"):
            with self.subTest(name=name):
                self.assertTrue(style.acceptable_class_name(name))

    def test_invalid_naming_is_still_caught(self) -> None:
        for name in ("c_health", "Bad_class", "C_bad", "S_", "S_some_name", "badservice"):
            with self.subTest(name=name):
                self.assertFalse(style.acceptable_class_name(name))

    def test_only_added_class_name_is_inspected(self) -> None:
        original = "class_name Old_unusual\nextends Node\n"
        current = original + "func action() -> void:\n\tpass\n"
        added = style.added_lines(original, current)
        self.assertEqual([], style.local_issues("sample.gd", current, added))

    def test_added_gdscript_naming_is_inspected(self) -> None:
        source = "class_name C_bad\nextends Component\n"
        issues = style.local_issues("c_bad.gd", source, style.added_lines(None, source))
        self.assertTrue(any("class_name" in issue for issue in issues))

    def test_renamed_script_preserves_original_baseline(self) -> None:
        import subprocess
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            def git(*cmd):
                subprocess.run(["git", *cmd], cwd=root, capture_output=True, check=True)
            git("init", "-q")
            git("config", "user.email", "test@example.invalid")
            git("config", "user.name", "Test")
            source = root / "old.gd"
            source.write_text("class_name Old_name\nextends Node\n", encoding="utf-8")
            git("add", ".")
            git("commit", "-qm", "initial")
            source.rename(root / "new.gd")
            git("add", "-A")
            origins = style.changed_origins(root, "HEAD")
            self.assertEqual("old.gd", origins["new.gd"])
            old = style.previous_text(root, origins["new.gd"], "HEAD")
            self.assertIn("Old_name", old)

    def test_added_whitespace_and_indentation(self) -> None:
        original = "extends Node\n  old_bad_indent\n"
        current = original + "func foo() -> void:\n  broken_line()\n\tpass \n"
        issues = style.local_issues("test.gd", current, style.added_lines(original, current))
        self.assertEqual(2, len(issues))

    def test_linter_filters_legacy_diagnostics_by_added_line(self) -> None:
        output = "x.gd:4:unused-argument:warning: old\nx.gd:9:function-name:error: new"
        issues, recognized = style.selected_lint_issues(output, {9}, False)
        self.assertTrue(recognized)
        self.assertEqual(1, len(issues))
        self.assertIn(":9:", issues[0])

    def test_linter_unparseable_nonzero_is_not_pass(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "n.gd").write_text("class_name C_Test\n", encoding="utf-8")
            bad = SimpleNamespace(returncode=1, stdout="unsupported flag", stderr="")
            with patch.object(style.subprocess, "run", return_value=bad):
                issues, skipped = style.inspect_file(root, "n.gd", None, "fake-binary")
            self.assertFalse(skipped)
            self.assertTrue(any("linter failed" in x for x in issues))

    def test_external_linter_disables_only_class_name(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "c_test.gd").write_text("class_name C_Test\nextends Resource\n", encoding="utf-8")
            commands = []
            def fake_run(cmd, **_kwargs):
                commands.append(cmd)
                return SimpleNamespace(returncode=0, stdout="", stderr="")
            with patch.object(style.subprocess, "run", side_effect=fake_run):
                issues, skipped = style.inspect_file(root, "c_test.gd", None, "gdscript-formatter")
            self.assertFalse(skipped)
            self.assertEqual([], issues)
            self.assertEqual(2, len(commands))
            self.assertEqual(["lint", "c_test.gd", "--max-line-length", "100", "--disable", "class-name"], commands[0][1:])
            self.assertEqual(["--check", "--verify-structure", "c_test.gd"], commands[1][1:])

    def test_explicit_formatter_path_can_be_used(self) -> None:
        import os
        with patch.dict(os.environ, {"GDSCRIPT_FORMATTER_BIN": "custom-formatter"}):
            with patch.object(style.shutil, "which", return_value="/tools/custom-formatter"):
                self.assertEqual("/tools/custom-formatter", style.formatter_binary(Path(".")))

    def test_invalid_explicit_formatter_does_not_fall_back(self) -> None:
        import os
        with patch.dict(os.environ, {"GDSCRIPT_FORMATTER_BIN": "missing-executable"}):
            with patch.object(style.shutil, "which", return_value=None):
                with self.assertRaises(RuntimeError):
                    style.formatter_binary(Path("."))

    def test_missing_formatter_is_not_pass(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "n.gd").write_text("class_name C_Test\n", encoding="utf-8")
            issues, skipped = style.inspect_file(root, "n.gd", None, None)
            self.assertEqual([], issues)
            self.assertTrue(skipped)

    def test_edited_legacy_does_not_demand_full_format(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            original = "extends Node\n  old_indent\n"
            (root / "n.gd").write_text(original + "func fresh() -> void:\n\tpass\n", encoding="utf-8")
            calls = []
            def fake_run(cmd, **_kwargs):
                calls.append(cmd)
                return SimpleNamespace(returncode=0, stdout="", stderr="")
            with patch.object(style.subprocess, "run", side_effect=fake_run):
                issues, skipped = style.inspect_file(root, "n.gd", original, "gdscript-formatter")
            self.assertFalse(skipped)
            self.assertEqual([], issues)
            self.assertEqual(1, len(calls))
            self.assertEqual("lint", calls[0][1])


if __name__ == "__main__":
    unittest.main()
