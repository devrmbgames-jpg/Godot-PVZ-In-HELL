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

Stages 1–2 implemented. Stage 1 commit: 274c57d5. Added native LimboAI priority tree with five reusable subtrees, single movement owner, staggered 5 Hz sight/hearing, actual-motion footsteps, light exposure, physical multi-point occlusion, last-seen search and escape. Existing service behavior is not yet migrated. Baseline `dev`; pre-existing GECS modification is untouched.

### Next

Commit stage 2, then migrate customer creation/departure/night reset into persistent NPC service roles and queue. Preserve case policy and all parcel/accounting contracts. Add traits/social reactions/hazard routing and then home delivery.

### Validation

Population/native-tree GUT: 5/5, 27 assertions PASS. Physical perception GUT: 4/4, 12 assertions PASS. Fresh-process parser: two batches of seven scripts, zero failures. Structure validation PASS. Navigation bake PASS (113 polygons). Fixed native BT null scene root in minimal fixtures with explicit scene-root hint. Live in-use scripts sometimes reject reload with error 43; fresh-process checks cover current disk code. Editor-only global settings writes are sandboxed; headless runtime checks require no such write. Full service/persistence regression and connected smoke remain pending.

### Owner QA / blockers

No blocker. Rendered behavior, readability and balance remain owner QA after automated acceptance.
