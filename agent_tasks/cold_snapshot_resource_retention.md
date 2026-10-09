# Cold snapshot Script / resource retention

Status: **DEFERRED**

## Task state

### Goal

Investigate the compile-only shutdown retention that predates Entity Templates / Traits.
Scope is the minimal snapshot/dependency probe below. Retention is a diagnostic symptom;
runtime leakage or a broken owner has not been established.

### Current

Controlled comparison establishes an **existing shutdown symptom, not introduced by №41**:

| Identical surface | Baseline | Current |
| --- | --- | --- |
| Control without snapshot reference | 1 checked, 0 failed; clean shutdown | Same, clean shutdown |
| Probe with snapshot reference | 1 checked, 0 failed; 280 Objects / 236 resources | 1 checked, 0 failed; 294 Objects / 247 resources |
| Native save-data GUT | 6/6, 40 assertions; clean shutdown | Same, clean shutdown |

Both probes additionally retain 3 texture RIDs and Variant allocator pages.
Their historical FAIL labels used the former zero-shutdown-diagnostics gate; raw logs remain.
The probe extends RefCounted; its method is deliberately never invoked, so GUT inheritance,
gameplay execution and snapshot capture execution are unnecessary for reproduction.
A Script/resource lifetime interaction is suspected; a project or engine owner is not proven.
Do not infer a common retaining owner or runtime leak from these shutdown counts.
The owner changed memory acceptance on 2026-10-10: repeated equivalent lifecycles stabilize
on both snapshots; this investigation no longer blocks [№41](refactoring_v2/41_entity_templates_traits.md).
See [growth evidence](../tests/fixtures/memory_lifecycle_evidence.json) and
[trend baseline](../tests/fixtures/memory_lifecycle_baseline.csv).

BASE_SHA: `857ec02d7703eab840dbf496730be48d29294d99`.
TARGET_SHA: `fc58024f827607286afd1d20d009e3bf22495f64`.
Same Godot **4.7.1.stable.official.a13da4feb**, GECS
`14d4282e5c1cb2713c187706ba2f5ff4e315d36e`, settings and byte-identical probes.
Engine/probe/test/settings hashes and results are saved in
[comparison evidence](../tests/fixtures/cold_snapshot_retention_evidence.json).

### Validation

Reproduce in separate isolated Git snapshots under an excluded location such as `.bin/`.
Use the same executable, pinned addon sources and baseline project settings for both.
Build each snapshot's native global-class/import cache; historical removed classes must come
from that snapshot. Import preparation is not an acceptance PASS if it reports diagnostics.
Copy the same two checked-in fixtures into both snapshots:

- [control](../tests/fixtures/cold_snapshot_retention_control.gd)
- [probe](../tests/fixtures/cold_snapshot_retention_probe.gd)

Run each independently in a **new headless process** (PowerShell; replace snapshot path):

```powershell
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --path <snapshot> --script res://utils/validate_district_scripts.gd -- res://tests/fixtures/cold_snapshot_retention_control.gd
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --path <snapshot> --script res://utils/validate_district_scripts.gd -- res://tests/fixtures/cold_snapshot_retention_probe.gd
.bin/Godot_v4.7.1-stable_win64_console.exe --headless --path <snapshot> --script res://addons/gut/gut_cmdln.gd -gtest=res://tests/gut/test_save_data.gd -gexit
```

Read stdout **and stderr** through process termination; preserve all diagnostics.
Parser/runtime errors fail. Shutdown-only retention is a measured symptom, not a leak verdict.
Captured results: `tests/artifacts/refactoring_v2_41_compare_same_probes.json`,
`...compare_{baseline,current}_cold_snapshot_retention_{control,probe}.log` and
`...compare_{baseline,current}_save_data_gut.log`.
Snapshots for this comparison reside in `.bin/retention_{baseline,current}_snapshot`;
ignored raw artifacts are supplementary; tracked evidence/fixtures permit reconstruction.

Acceptance for a future repair: isolate and document the retaining owner or engine contract;
preserve parser/runtime and save-data behavior, demonstrate the effect on the same probe,
and verify repeated lifecycles do not grow. A clean shutdown would resolve the symptom;
retention alone is insufficient justification for changing gameplay ownership.
No repair has been implemented. Do not expand into unrelated runtime work.

### Owner QA / blockers

Deferred independent diagnostic investigation; engine involvement remains a hypothesis.
No warning suppression, addon edit or dependency upgrade is authorized.
The explicit owner decision is implemented in AGENTS.md and memory/testing/refactoring skills.
Rendered gameplay / visual QA is not needed for this reproduction.
