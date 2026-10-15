# PERSIST-DORM01 — Retained dormant body after snapshot restore

Status: **DONE**
Priority: **P1**
BASE_SHA: `495cf8f6d9fb0ea3dc0fbc62b5cef32f18971103`
TARGET_SHA: `e3337db2d7d634ed6ceb5c57d4212f347249b9cb`

## Task state

### Goal
Resolve the existing native persistence baseline failure for a retained dormant NPC. Determine whether the golden fixture violates the current authority contract or restore/reconciliation incorrectly enables the body. Preserve retained identity, health/inventory, stable IDs and the declared dormant-state contract; do not waive the assertion merely to make the check pass.

### Evidence / scope
After the owner-requested ConfigFile rollback, production adapter and fixtures exactly match HEAD (binary PVZH1, schema 19). `test_refactoring_v2_persistence_baseline.gd` passes 4/5 tests, 364/365 assertions; the sole failure is line 289, `assert_false(dormant_body.enabled)`. Golden snapshot roundtrip and retained-body identity assertions pass. Log `.artifacts/godot_agent/gut-20261015-164821293.stdout.log` / `.stderr.log`.

The same dormant assertion also failed while testing the extracted old binary adapter, before fallback. This is separate from the ConfigFile Float64 mismatch. Current owners: WorldSnapshotService, district restore/reconciliation, DistrictPopulationService, O_DistrictLifecycle, the native baseline fixture/test.

### Current
Root cause: explicit bootstrap/restore reconciliation reused the calendar-fact planner; its already-planned retry called `_try_arrival()` and changed a saved OUTSIDE placement to STREET. `O_DistrictLifecycle` now preserves an existing current-day/phase plan for the explicit reconciliation command and assigns only missing plans. Real calendar facts and explicit phase-plan retries retain their existing behavior. No saved fields, schema, fixtures, IDs or body ownership changed.

Added MANUAL-command regressions for saved dormancy with both completion states and for a genuinely missing plan. The original golden retained-body regression passes unchanged. Architecture and obligation docs describe the explicit reconstruction boundary.

### Next
Implementation, verification and review are complete. Continue PVZ-A03 documentation against the supported binary format; ConfigFile migration remains owner-deferred.

### Validation
PASS: DistrictLifecycle 21/21, 196 assertions (`.artifacts/godot_agent/gut-20261015-165456155.stdout.log`). PASS: native current-format persistence baseline 5/5, 365 assertions, engine exit 0 (`gut-20261015-165515554.stdout.log`), including the original failure and health/inventory/retained identity checks. The wrapper reports FAIL on that suite solely for unchanged shutdown Resource/RID/allocator retention diagnostics; logs are preserved and classified KNOWN_ENGINE_LIMITATION / DEFERRED per AGENTS.md, not hidden or relabelled as wrapper PASS.

PASS: WorldSnapshot 37/37, 464 assertions (`gut-20261015-165613749.stdout.log`), StartupRestore 5/5, 38 assertions (`gut-20261015-165627095.stdout.log`). Across these four focused suites: 68 tests, 1,063 assertions; the baseline wrapper limitation is reported separately above.

PASS: two-process Night write/retry/fresh Morning restore, including replacement Morning 3: `tests/artifacts/night_persistence-write-20261016-025645380.log` and `night_persistence-restore-20261016-025658540.log`. PASS: formatter/lint, agent smells, strict architecture, full project structure and native ParseChanged (`.artifacts/godot_agent/parsechanged-20261015-165712971.stdout.log`). Immutable review PASS: `/root/review_cal01` inspected the exact BASE_SHA/TARGET_SHA above read-only; architecture/style PASS, no material findings. Main triage: no accepted P0/P1/P2 remain. Reviewer validation NOT_RUN; executed native checks are listed separately. Gameplay/visual NOT_RUN, 0/8.

### Dependencies / exclusions
Independent of deferred [PVZ-B01](../pvz_b01_configfile_save_storage.md) format migration. Follow GECS, typed GDScript, native scene ownership and task lifecycle. No economy redesign, NPC performance work, random-seed changes or broad golden regeneration.

### Owner QA / blockers
No owner decision currently required. Preserve unrelated user task/design edits and addon changes.

### Completion
Record exact base/target/fix SHA and real results. Archive only after required verification/review and no accepted material findings remain.
