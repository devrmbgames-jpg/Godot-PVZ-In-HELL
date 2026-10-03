# Living district

Status: **DONE**

## Accepted contract

Implement the agreed living district plan: eight residents and four recurring visitors; permanent identity and death; phase-based schedules; LimboAI decisions; sight/hearing/search; four personalities and seven supernatural traits; preserved parcel service/accounting; witnessed social memory; gradual replacement; two optional evening deliveries; incompatible old saves.

No rendered playtest or visual capture is authorized. Preserve the existing dirty `addons/gecs` checkout; addons are read-only. Work on `dev` and commit coherent stages without pushing.

## Stages

1. District blockout, persistent population, participation lifecycle, schedules and save schema.
2. LimboAI, perception, pursuit/search/flee, repeated encounters.
3. Persistent NPC service role and queue; preserve delivery/refusal/inspection/complaints/accounting.
4. Personalities, supernatural traits and fire aura replacing ordinary lava challenges.
5. Street conversations, witnessed memories, bounded ambient conflict, loot and replacement.
6. Evening delivery, focused regression and headless district smoke; owner QA.

## Task state

### Goal

Complete all six accepted implementation stages and their focused validation.

### Current

Stages 1–6 implemented. Commits: 274c57d5 (foundation), 6e37f466 (AI/perception), 9d0dd5fd (service roles), 21d78a56 (intrinsic traits/routing), 43a00509 (community), 1be478f8 (home delivery and acceptance). Stage 6 adds two optional real-box home deliveries, door-local inspection, idempotent base/bonus payment and failed promises; sleep safety gates, complete district snapshot validation and restoration of derived AI. Shared dialogue interface has separate street/service adapters. Pickup reservations release on interruption, absence, Night and restore. Nearby authored cover points support search. Main dev and the pre-existing dirty GECS checkout are preserved. Windows QA exported from 1be478f8.

Owner corrected district placement and warehouse navmesh after finding the original layout/nav bake regression. The correction keeps the owner's current main_level and baked mesh intact. Bake utility now duplicates the authored mesh, collects its configured group once in region coordinates, checks native coverage/connectivity before writing and preserves settings/UID. Project map cell height matches the owner's 0.1 mesh. Lost authored hazard-route graph links are restored without changing positions. Navigation checks are shared with the week smoke; isolated native GUT cases reject missing coverage and partial paths.

### Next

Owner rendered acceptance of the current dev main_level, full-day behavior and balance are tracked only in qa_tasks/living_district.md. No implementation work remains in the accepted living district goal.

### Validation

2026-10-04 navigation correction: owner's saved 307-polygon mesh and an in-memory 317-polygon rebake both PASS: 42 covered points, 41 complete counter routes, 13 connected hazard-route junctions and 36 traversable directed edges. All stored bake settings are preserved; main_level, district_blockout and the owner's baked navmesh are unchanged. Primitive dry bake PASS (101 polygons); its authored 0.3 agent radius still produces Godot's voxel-rounding warning. Native navigation GUT 4/4 (7 assertions), population GUT 5/5 (27): PASS. Four changed scripts passed fresh-process parser and final MCP diagnostics with no relevant script warnings/errors. Whitespace PASS. Structure check reports only the pre-existing task-state document failure described below. Updated seven-day smoke PASS, tests/artifacts/district-20261004-050915657.log: navigation preflight succeeds, mornings 2–8 retain twelve records/bodies and restoration succeeds without duplicates. No rendered playtest ran. The earlier Windows QA build predates the owner's level correction.

2026-10-04: main regression 126/126 (975 assertions), additional combat/interaction regression 30/30 (218), final district snapshot/retry/sleep feedback 9/9 (60): PASS. New acceptance covers visible killing versus wall occlusion, circuit toggling, anonymous physical interaction sound, exclusive pickup reservation, phase conflict budget with self-defense, home inspection and interruption, real failed-write retry with replacement/promise conservation. Fresh-process parser checked 92 changed scripts, then five closeout and three final presentation scripts: zero failures and no script warnings/errors. Structure and diff whitespace PASS. Clean navigation bake PASS (132 polygons). Final seven-day runner PASS, tests/artifacts/district-20261004-041459990.log, mornings 2–8 retain twelve identities/bodies and reload without duplicates. Smoke phases last 720 physics frames and cannot establish full-day balance. No rendered playtest or visual capture ran.

Windows QA: .export/windows/20261003-182317Z-1be478f8-living-district/PVZInHell.exe. Packaged menu and main level each PASS at 120 headless frames; build_info.json records the source commit, QA save profile and pending owner QA. Exporter reports editor-addon reload errors, but packaged runtime logs have no script/runtime errors other than the known Windows certificate-store message. Addons were not edited. .export/LATEST.cmd points to this build.

### Owner QA / blockers

No gameplay blocker. Repository structure validation currently reports five missing task-state headings in the pre-existing agent_tasks/gdscript_readability_cleanup.md; its blob is unchanged from HEAD (5372dc4eb04f8e51ffaab39b58c944729b7978b3). No additional structure failure is reported for this correction. Rendered behavior, readability and balance remain owner QA after automated acceptance.
