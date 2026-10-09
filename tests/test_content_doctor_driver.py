"""Acceptance-driver regressions distinguish deferred shutdown from actual engine failures."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "utils"))
from validate_content_doctor import diagnostic_failures

HEADER = "Godot Engine v4.7.1.stable.official\n"
COMPLETE = "CONTENT_DOCTOR_COMPLETE\n"


class ContentDoctorDriverTests(unittest.TestCase):
    def test_runtime_error_is_never_deferred(self) -> None:
        failures, deferred = diagnostic_failures(
            HEADER + "ERROR: 3 RID allocations of type 'Body' were leaked at exit.\n" + COMPLETE
        )
        self.assertEqual(len(failures), 1)
        self.assertEqual(deferred, [])

    def test_known_shutdown_retention_preserves_deferred_evidence(self) -> None:
        failures, deferred = diagnostic_failures(
            HEADER + COMPLETE
            + "WARNING: ObjectDB instances leaked at exit (run with --verbose for details).\n"
            + "WARNING: 12 resources still in use at exit.\n"
            + "Leaked instance: GDScript:100\nLeaked instance: Resource:101\n"
        )
        self.assertEqual(failures, [])
        self.assertEqual(len(deferred), 2)

    def test_actual_node_retention_remains_failure(self) -> None:
        failures, _ = diagnostic_failures(
            HEADER + COMPLETE
            + "WARNING: ObjectDB instances leaked at exit (run with --verbose for details).\n"
            + "Leaked instance: Node:100\nLeaked instance: GDScript:101\n"
        )
        self.assertTrue(any("Node" in failure for failure in failures))

    def test_unknown_warning_after_complete_is_failure(self) -> None:
        failures, deferred = diagnostic_failures(HEADER + COMPLETE + "WARNING: Collider missing\n")
        self.assertEqual(failures, ["WARNING: Collider missing"])
        self.assertEqual(deferred, [])

    def test_no_complete_marker_or_different_engine_cannot_defer(self) -> None:
        for prefix in [HEADER, HEADER.replace("4.7.1", "4.8.0") + COMPLETE]:
            with self.subTest(prefix=prefix):
                failures, deferred = diagnostic_failures(
                    prefix + "WARNING: 12 resources still in use at exit.\n"
                )
                self.assertEqual(len(failures), 1)
                self.assertEqual(deferred, [])


if __name__ == "__main__":
    unittest.main()
