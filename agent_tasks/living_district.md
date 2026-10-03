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

Stages 1–4 implemented. Commits: 274c57d5 (foundation), 6e37f466 (AI/perception), 9d0dd5fd (service roles). Intrinsic rules use shared perception, warnings and cached personal incident reactions. Fire aura uses existing hazard factory/follow/damage with real typed immunity. A passage graph with two bypasses compares actual navmesh routes and effective damage; final arrival semantics stay unchanged. Baseline dev; pre-existing GECS modification is untouched.

### Next

Implement street dialogue, loot, bounded conflicts, distinct replacements and evening home delivery. Merchant replacement needs its catalog/action; caches/BT state must reset on snapshot restore; disabled NPC inventory ownership must be permitted in snapshot graph; full save roundtrip/domain validation and connected district smoke still needed.

### Validation

Population/native-tree GUT 5/5 (27 assertions), physical perception 4/4 (12), district service 8/8 (41), intrinsic rules/risk 8/8 (36), existing customer flow/timing/dialogue 48/48 (465): PASS. Fresh-process parser batches (7, 7, 6, 6 scripts) zero failures. Structure PASS. Navigation bake PASS (113 polygons). Live in-use scripts sometimes reject reload with error 43; fresh-process checks cover disk code. Full persistence regression and connected smoke remain pending.

### Owner QA / blockers

No blocker. Rendered behavior, readability and balance remain owner QA after automated acceptance.
