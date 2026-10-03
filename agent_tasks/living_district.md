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

Stages 1–3 implemented. Commits: 274c57d5 (foundation), 6e37f466 (AI/perception). Persistent district now binds new daily cases to lifetime IDs, enqueues retained bodies, reserves one counter through R_NpcServiceAt, and releases appearances without deleting the person. Native tree executes service timers. Legacy no-district fixtures retain their original implementation. Permanent death reaches every case. Night clears appearances while retaining bodies. Baseline `dev`; pre-existing GECS modification is untouched.

### Next

Commit stage 3. Implement personalities and intrinsic supernatural rules, fire damage/resistance, aura lifecycle and hazard-aware routes; then witnessed incidents, street dialogue, loot, distinct replacement names/profiles and evening home delivery. Important remaining details: merchant replacement needs its catalog/action; caches/BT state must reset on snapshot restore; disabled NPC inventory ownership must be permitted in snapshot graph; full save roundtrip/domain validation and connected district smoke still needed.

### Validation

Population/native-tree GUT 5/5 (27 assertions), physical perception 4/4 (12), district service 8/8 (41), existing customer flow/timing/dialogue 48/48 (465): PASS. Three fresh-process parser batches (7, 7, 6 scripts) zero failures. Structure PASS. Navigation bake PASS (113 polygons). Native BT null scene-root fixture issue fixed. Live in-use scripts sometimes reject reload with error 43; fresh-process checks cover disk code. Editor-only global settings writes are sandboxed; headless runtime checks require no such write. Full persistence regression and connected smoke remain pending.

### Owner QA / blockers

No blocker. Rendered behavior, readability and balance remain owner QA after automated acceptance.
