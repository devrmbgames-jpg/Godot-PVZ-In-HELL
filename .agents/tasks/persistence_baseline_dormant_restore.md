# PERSIST-DORM01 — Retained dormant body after snapshot restore

Status: **IN_PROGRESS**
Priority: **P1**
BASE_SHA: `de19b8ea28d3ca3d3d4493d4516d62a27b1a05c9`

## Task state

### Goal
Resolve the existing native persistence baseline failure for a retained dormant NPC. Determine whether the golden fixture violates the current authority contract or restore/reconciliation incorrectly enables the body. Preserve retained identity, health/inventory, stable IDs and the declared dormant-state contract; do not waive the assertion merely to make the check pass.

### Evidence / scope
After the owner-requested ConfigFile rollback, production adapter and fixtures exactly match HEAD (binary PVZH1, schema 19). `test_refactoring_v2_persistence_baseline.gd` passes 4/5 tests, 364/365 assertions; the sole failure is line 289, `assert_false(dormant_body.enabled)`. Golden snapshot roundtrip and retained-body identity assertions pass. Log `.artifacts/godot_agent/gut-20261015-164821293.stdout.log` / `.stderr.log`.

The same dormant assertion also failed while testing the extracted old binary adapter, before fallback. This is separate from the ConfigFile Float64 mismatch. Current owners: WorldSnapshotService, district restore/reconciliation, DistrictPopulationService, O_DistrictLifecycle, the native baseline fixture/test.

### Current
Confirmed exact failing assertion after full storage rollback. Root cause not yet established. Known engine shutdown-only Resource/RID retention remains separately KNOWN_ENGINE_LIMITATION / DEFERRED; actual test failure is not waived by that policy.

### Next
Inspect the saved record/body availability and restore → explicit district reconciliation boundary. Make the smallest contract-correct fix, validate focused persistence/district checks and one relevant non-visual Night restore integration. Commit a coherent checkpoint and run one immutable read-only reviewer; triage/fix accepted P0/P1/P2 before DONE.

### Validation
FAIL: original baseline 4/5 as above. PASS: parser after rollback, `.artifacts/godot_agent/parsefiles-20261015-164813005.stdout.log`. Implementation/targeted review NOT_RUN. Gameplay/visual NOT_RUN, 0/8.

### Dependencies / exclusions
Independent of deferred [PVZ-B01](pvz_b01_configfile_save_storage.md) format migration. Follow GECS, typed GDScript, native scene ownership and task lifecycle. No economy redesign, NPC performance work, random-seed changes or broad golden regeneration.

### Owner QA / blockers
No owner decision currently required. Preserve unrelated user task/design edits and addon changes.

### Completion
Record exact base/target/fix SHA and real results. Archive only after required verification/review and no accepted material findings remain.
