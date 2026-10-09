# Cold snapshot Script / resource retention

Status: **PLANNED**

## Task state

### Goal

Resolve the compile-only shutdown retention that predates Entity Templates / Traits.
Scope is the minimal snapshot/dependency probe below; №41's native district regression RV-003
remains owned by [№41](refactoring_v2/41_entity_templates_traits.md).

### Current

Controlled comparison establishes **existing defect, not introduced by №41**:

| Identical surface | Baseline | Current |
| --- | --- | --- |
| Control without snapshot reference | 1 checked, 0 failed; clean shutdown | Same, clean shutdown |
| Probe with snapshot reference | 1 checked, 0 failed; 280 Objects / 236 resources | 1 checked, 0 failed; 294 Objects / 247 resources |
| Native save-data GUT | 6/6, 40 assertions; clean shutdown | Same, clean shutdown |

Both failing probes additionally retain 3 texture RIDs and Variant allocator pages.
Exit code 0 is **FAIL** because native WARNING/ERROR diagnostics remain.
The probe extends RefCounted; its method is deliberately never invoked, so GUT inheritance,
gameplay execution and snapshot capture execution are unnecessary for reproduction.
A Script/resource lifetime interaction is suspected; a project or engine owner is not proven.
Do not label the entire shutdown-retention family as this defect or waive №41 acceptance.

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

Read stdout **and stderr** through process termination; require zero errors/warnings.
Captured results: `tests/artifacts/refactoring_v2_41_compare_same_probes.json`,
`...compare_{baseline,current}_cold_snapshot_retention_{control,probe}.log` and
`...compare_{baseline,current}_save_data_gut.log`.
Snapshots for this comparison reside in `.bin/retention_{baseline,current}_snapshot`;
ignored raw artifacts are supplementary; tracked evidence/fixtures permit reconstruction.

Acceptance: control and probe parse with clean shutdown, native save-data remains 6/6 clean,
required formatter/parser/static checks PASS, and the diagnosed ownership is documented.
No fix has been implemented or verified. Do not expand into unrelated runtime repairs.

### Owner QA / blockers

Fix ownership needs isolation; engine involvement remains a hypothesis.
No warning suppression, relaxed gate, addon edit or dependency upgrade is authorized.
Separating this defect does not change №41's mandatory zero-diagnostics criterion.
A criterion change or dependency upgrade requires a concrete owner decision before adoption.
Rendered gameplay / visual QA is not needed for this reproduction.
