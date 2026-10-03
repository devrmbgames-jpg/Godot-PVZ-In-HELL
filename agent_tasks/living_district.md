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

Stages 1–6 implemented. Commits: 274c57d5 (foundation), 6e37f466 (AI/perception), 9d0dd5fd (service roles), 21d78a56 (intrinsic traits/routing), 43a00509 (community), 1be478f8 (home delivery and acceptance). Stage 6 adds two optional real-box home deliveries, door-local inspection, idempotent base/bonus payment and failed promises; sleep safety gates, complete district snapshot validation and restoration of derived AI. Shared dialogue interface has separate street/service adapters. Pickup reservations release on interruption, absence, Night and restore. Nearby authored cover points support search. Main dev and the pre-existing dirty GECS checkout are preserved. Windows QA exported from 1be478f8; no implementation work remains.

### Next

Owner rendered acceptance, full-day behavior and balance are tracked only in qa_tasks/living_district.md.

### Validation

2026-10-04: main regression 126/126 (975 assertions), additional combat/interaction regression 30/30 (218), final district snapshot/retry/sleep feedback 9/9 (60): PASS. New acceptance covers visible killing versus wall occlusion, circuit toggling, anonymous physical interaction sound, exclusive pickup reservation, phase conflict budget with self-defense, home inspection and interruption, real failed-write retry with replacement/promise conservation. Fresh-process parser checked 92 changed scripts, then five closeout and three final presentation scripts: zero failures and no script warnings/errors. Structure and diff whitespace PASS. Clean navigation bake PASS (132 polygons). Final seven-day runner PASS, tests/artifacts/district-20261004-041459990.log, mornings 2–8 retain twelve identities/bodies and reload without duplicates. Smoke phases last 720 physics frames and cannot establish full-day balance. No rendered playtest or visual capture ran.

Windows QA: .export/windows/20261003-182317Z-1be478f8-living-district/PVZInHell.exe. Packaged menu and main level each PASS at 120 headless frames; build_info.json records the source commit, QA save profile and pending owner QA. Exporter reports editor-addon reload errors, but packaged runtime logs have no script/runtime errors other than the known Windows certificate-store message. Addons were not edited. .export/LATEST.cmd points to this build.

### Owner QA / blockers

No blocker. Rendered behavior, readability and balance remain owner QA after automated acceptance.
