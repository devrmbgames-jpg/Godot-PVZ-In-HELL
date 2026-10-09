"""Verify that trend summaries distinguish stable counts from accumulating survivors."""
import unittest

from measure_memory_lifecycle import slope, summarize


class MemoryTrendTests(unittest.TestCase):
    def test_short_series_does_not_divide_by_zero(self):
        self.assertEqual(slope([42.0]), 0.0)

    def test_accumulating_objects_have_positive_full_and_tail_trend(self):
        rows = [self.sample(index, 100 + index) for index in range(11)]
        metrics = summarize(rows)["scenario"]["metrics"]["objects"]
        self.assertEqual(metrics["slope_per_cycle"], 1.0)
        self.assertEqual(metrics["tail_slope_per_cycle"], 1.0)
        self.assertGreater(metrics["last_block_median"], metrics["first_block_median"])

    def test_warmup_allocation_is_excluded_from_measured_slope(self):
        rows = [self.sample(0, 10)] + [self.sample(index, 100) for index in range(1, 11)]
        metrics = summarize(rows)["scenario"]["metrics"]["objects"]
        self.assertEqual(metrics["slope_per_cycle"], 0.0)
        self.assertEqual(metrics["tail_slope_per_cycle"], 0.0)
        self.assertEqual(metrics["first_block_median"], metrics["last_block_median"])

    @staticmethod
    def sample(iteration, objects):
        return {"scenario": "scenario", "iteration": iteration, "objects": objects,
                "rss": 1000, "private_bytes": 1000, "memory_static": 500,
                "resources": 5, "nodes": 2, "orphans": 0}


if __name__ == "__main__":
    unittest.main()
