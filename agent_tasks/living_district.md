# Living district

Status: **IN_PROGRESS**

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

Stage 1 foundation implemented: authored eight residents/four visitors and seven rules, persistent records/bodies, native participation, phase scheduling, delayed resettlement, district blockout, snapshot schema 2 and nighttime preparation. Existing service behavior is not yet migrated. Baseline `dev`; pre-existing GECS submodule modification is untouched.

### Next

Finish stage 1 navigation/parser verification and commit. Then implement LimboAI decision subtrees, sight/hearing/search and an intent arbiter; migrate transient customer service onto permanent bodies.

### Validation

Population GUT: 4/4 tests, 23 assertions PASS. Structure validation PASS. Editor parser imports report no project parse errors; in-use script reloads sometimes return error 43, so fresh headless parser validation remains required. Editor-only headless exit cannot save global editor settings within the sandbox; runtime/GUT does not require that write. Full service/persistence regression and connected smoke remain pending.

### Owner QA / blockers

No blocker. Rendered behavior, readability and balance remain owner QA after automated acceptance.
