"""The formatter gate must never rewrite new or strict-checked source files."""

from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from utils.check_gdscript_format import inspect_file


class FormatterReadOnlyTests(unittest.TestCase):
    def test_new_and_strict_checks_keep_verify_structure_read_only(self):
        for previous, strict in [(None, False), ("## Older source\n", True)]:
            with self.subTest(strict=strict), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                source = root / "sample.gd"
                original = b"extends RefCounted\n## Example immutable operation.\nclass_name Sample\n"
                source.write_bytes(original)
                calls = []

                def run_formatter(command, **_options):
                    calls.append(command)
                    # The real CLI writes unless --check is present, including verify mode.
                    if "lint" not in command and "--check" not in command:
                        source.write_text("unexpected rewrite", encoding="utf-8")
                    return subprocess.CompletedProcess(command, 0, stdout="", stderr="")

                with patch("utils.check_gdscript_format.subprocess.run", run_formatter):
                    issues, skipped = inspect_file(root, "sample.gd", previous, "formatter",
                                                   strict=strict)
                self.assertEqual(issues, [])
                self.assertFalse(skipped)
                self.assertEqual(source.read_bytes(), original)
                verification = [command for command in calls if "--verify-structure" in command]
                self.assertEqual(len(verification), 1)
                self.assertIn("--check", verification[0])


if __name__ == "__main__":
    unittest.main()
