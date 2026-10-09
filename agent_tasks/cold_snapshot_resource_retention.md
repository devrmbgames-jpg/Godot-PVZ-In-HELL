# Cold snapshot Script / resource retention

Status: **DEFERRED**
Diagnostic status: **KNOWN_ENGINE_LIMITATION / DEFERRED**

## Task state

### Goal

Preserve the existing shutdown-retention baseline; reconsider only after the project moves
to stable Godot 4.8+ with the relevant upstream fixes checked. No independent investigation
on Godot 4.7.1 is authorized. Godot 4.7.2 migration is not planned.

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
The owner classifies shutdown-only GDScript/GDScriptNativeClass/Resource/StringName/RID retention
on Godot 4.7.1 as a known engine lifecycle limitation. No individual upstream cause was isolated.
Do not infer a common retaining owner or runtime leak from these shutdown counts.
Owner policy on 2026-10-10: `KNOWN_ENGINE_LIMITATION / DEFERRED`; do not block tasks or investigate
this shutdown-only category before stable Godot 4.8+. Repeated equivalent lifecycles stabilize
on both snapshots; this investigation no longer blocks [№41](completed/refactoring_v2/41_entity_templates_traits.md).
See [growth evidence](../tests/fixtures/memory_lifecycle_evidence.json) and
[trend baseline](../tests/fixtures/memory_lifecycle_baseline.csv).

BASE_SHA: `857ec02d7703eab840dbf496730be48d29294d99`.
TARGET_SHA: `fc58024f827607286afd1d20d009e3bf22495f64`.
Same Godot **4.7.1.stable.official.a13da4feb**, GECS
`14d4282e5c1cb2713c187706ba2f5ff4e315d36e`, settings and byte-identical probes.
Engine/probe/test/settings hashes and results are saved in
[comparison evidence](../tests/fixtures/cold_snapshot_retention_evidence.json).

### Validation

The commands below preserve the historical Godot 4.7.1 reproduction; they are not a next action.
After adoption of stable Godot 4.8+, check relevant upstream fixes and compare the existing
reproduction using the new stable engine with matched project/dependency/settings.
Use separate isolated Git snapshots under an excluded location such as `.bin/`.
Build each snapshot's native global-class/import cache; historical removed classes must come
from that snapshot. Import preparation does not prove parser/runtime acceptance; classify
any diagnostics under the current engine policy.
Copy the same two checked-in fixtures into both snapshots:

- [control](../tests/fixtures/cold_snapshot_retention_control.gd)
- [probe](../tests/fixtures/cold_snapshot_retention_probe.gd)

Historical commands used separate **new headless processes** (PowerShell; snapshot path):

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

Revisit condition: the project uses stable Godot 4.8+ and relevant upstream fixes have been
checked. Record whether the historical symptom persists, without inferring a runtime leak
from shutdown counts. Do not change typing, reference management, WeakRef, free() or GECS
solely to remove shutdown warnings. No repair has been implemented.

### Owner QA / blockers

`KNOWN_ENGINE_LIMITATION / DEFERRED` under the explicit owner decision; no active investigation.
Proven runtime memory growth, lost Nodes, use-after-free, double-free and reproducible runtime
regressions remain defects requiring repair and are outside this shutdown-only deferral.
No warning suppression, addon edit or dependency upgrade is authorized.
The explicit owner decision is implemented in AGENTS.md and memory/testing/refactoring skills.
Rendered gameplay / visual QA is not needed for this reproduction.
