# R26.2 — NPC archetypes, composable traits and persistent variation
Status: **IN_PROGRESS**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Implement **base archetype + mandatory/compatible optional traits + persistent per-person variation**,
so later combinations can be authored without central NPC-type code changes.

### Current

Live initial/replacement population now commits deterministic NpcVariation before publication.
NpcRecord references immutable DEF_NpcArchetype; its name and mandatory/selected optional traits
are read-only resolved views. Compiler instance fields compose speed, damage resistance and
receiver tags. Native MCP migrated all 12 existing profiles and the district while preserving
paths, keys, schedules, roles and places. They retain existing behavior; the ten requested
archetypes are authored assets awaiting live roster binding and new behavior implementation.
Schema 16 rejects incomplete/unsupported records before mutation; restore never rerolls.
Category ordering now commits real catalog payloads with the existing receiving batch/parcel IDs.
Weighted available categories feed deterministic per-person decisions; missing categories fall back.
Contents and the terminal/archive arrival projection retain the choice through retry/restore.
Native MCP adds all 15 physical catalog items while preserving all eight authored case paths.
Category checkpoint review PASS. Next: implement R26.3/R26.4 and bind all ten requested archetypes.
Night presentation has native authored spatial audio/Decal views and typed immutable tuning;
its focused lifecycle checks, independent checkpoint review and district smoke pass in R26.3.
Full presentation/combat/mandatory behavior acceptance remains open.

### Validation

Foundation/catalog/integration/category implementation and independent reviews PASS at
`473e1569425d9c6bcd809828c3c8422e6280b66f`,
`ca6bc069c5645028fd9b51e681d9364291e6f32c`,
`3bfdde24cd8d7cdf6d2961637edd0aa07ebcc174`; unique checks remain in those Git checkpoints.
RV-001 holy eligibility FIXED `a02e250b80a4b984e662854452f8cc110e356660`;
RV-002 inspected-subresource ownership FIXED `fd2627ee7e6312efbc6c5a9afb70b77fa997ce1f`;
RV-003 reused-body variation reconciliation FIXED `a081b0037081f117c0435af443c53fb2f626de70`.
All targeted reviews PASS; architecture/style PASS, reviewer runtime NOT_RUN.
Category GUT214635170 7/199, receiving213649524 22/151, contents213920106 14/244,
truck214703675 14/96, world214710999 35/443, terminal214819154 7/28 PASS.
Week smoke district-20261012-075624916.log PASS. Exact category checkpoint evidence remains in Git.
Schema16 now covers Strength and complete soul receipts/ledger:
`3a18bbc5275463d05328744e767e923cf8242d7b`, repaired/reviewed `4f956de8db9a62aa8bd13df53c150025798aa1d0` PASS; details in R26.3.
Latest world snapshot052321580 35/443 and soul053521718 16/186 PASS;
golden baseline052241040 5/362 assertions PASS, runner FAIL solely at engine shutdown.
Static persistence baseline PASS. Specified shutdown Resource/RID/VariantPools retention
KNOWN_ENGINE_LIMITATION/DEFERRED. Global MCP reload43 NOT_PASS; fresh native CLI verifies separately.

### Owner QA / blockers

Subjective gameplay, dialogue, assets and balance require owner QA after implementation.
Required owner acceptance remains open; explicitly deferred polish gets a QA checklist.

## Required data model

Prefer authored Resources instead of hard-coded type switches.

Introduce/extend a base archetype definition containing:
- archetype key/display label, physical scene/appearance and two or more placeholder names;
- mandatory traits, optional weighted pool and incompatible trait rules;
- base personality/social tuning and item order category weights;
- dialogue variant paths/keys and combat preference (melee/ranged/avoid);
- receiver/species tags for holy/unholy/blood/fire rules;
- presentation hooks as data, with no direct UI/audio ownership.

Keep `DEF_NpcTrait` as reusable behavior capability. If the current fixed enum becomes a bottleneck, migrate toward authored trait definitions/keys rather than adding one giant enum/match forever.

`DEF_NpcTrait` is NPC behavior/tuning data; Entity Traits compose C/R capabilities through
the existing `E_TraitedEntity.traits` compiler. Extend that boundary rather than inventing
another runtime composition registry. `C_District.people` owns `NpcRecord` aggregates;
runtime Components/Relationships retain live state/bindings without a second identity store.

### Persistent person variation

Do not mutate shared profile Resources at runtime.

Persist on `NpcRecord` (or a dedicated persistent nested contract):
- archetype key/reference;
- stable variation seed;
- selected name;
- selected dialogue variant;
- selected optional trait keys;
- any rolled personality/tuning modifiers that must survive reload.

A save/load of the same person must reproduce the same name/traits/dialogue variant.

Replacement/new NPC may roll a new seed and therefore a different valid combination.

Trait selection must:
- include all mandatory archetype traits;
- choose only compatible optional traits;
- be deterministic from the stored seed;
- have explicit bounded counts/weights;
- never reroll every scene load.

Derive choices through `DecisionRandomRules` from the durable world seed, stable NPC ID
and a named creation decision. Commit selected values once. No independent global RNG,
frame-time/instance-ID seed or sequence advance during preview/reload.

## Placeholder names

Use two initial names per archetype; they are placeholders and must live in authored data.

- Скромник: **Тихон**, **Мирон**; Плачущий ангел: **Сераф**, **Азариэль**.
- Ночной охотник: **Морок**, **Нокт**; Карга: **Морана**, **Аграфена**.
- Бугай: **Гром**, **Бран**; Огненный элементаль: **Пирос**, **Углик**.
- Потерянный: **Лука**, **Ян**; Цепной дьявол: **Азгар**, **Мальх**.
- Жуткий: **Шорох**, **Хрип**; Вампир: **Северин**, **Владен**.

## Archetypes and mandatory behavior traits

### Скромник
Dislikes direct gaze, observes others while avoiding being observed, and escalates sustained
player staring to aggression. Orders strongly favor CLOTHING. Optional variation controls
patience, observation distance and timid/resentful social response.

### Плачущий ангел
Moves/attacks only while unobserved, including aggression; aggressive speed is several times
peaceful speed, authored as tuning. Only HOLY meaningfully hurts it; other NPCs strongly avoid
voluntary conflict. Uses signs/boards instead of spoken dialogue; orders ARTIFACT.
Visibility uses the actual player camera/frustum/line of sight, never an omniscient boolean.

### Ночной охотник
Darkness produces aggressive attacks; light produces peaceful/flee behavior, with retreat
from sufficiently bright zones. Appearance warns through music and denser shadows without
presentation owning AI state. Orders WEAPON + CLOTHING. Preserve authored light-zone/circuit
queries; do not introduce renderer sampling or repeated route light scans.

### Карга
Deceptive dialogue/riddles, long-lived grudges affecting later reactions, ranged combat
preference; orders REAGENT + ARTIFACT.

### Бугай
Respects demonstrated strength, dislikes weakness, speaks threateningly. Orders WEAPON with
low-probability TOY, prefers a private unpacking booth. Player witnessing it holding/unpacking
a toy immediately triggers attack through actual perception/visibility, never global knowledge.

### Огненный элементаль
Fire immune; fire aura and thin floor Hazard with authored default radius **10 m** encourage
the player to get off the floor through real hazard rules, never teleportation. Orders strongly
favor fire REAGENT; often opens parcels immediately, with authored explosion probability for
relevant contents held/opened. Reuse hazard/damage owners; commit the roll once per opening.

### Потерянный
Neutral baseline/control archetype with medium aggression, no required supernatural rule,
and orders from any available category.

### Цепной дьявол
Repeated appropriate soul offers, easy to anger, fire immune; orders WEAPON + ARTIFACT,
sometimes CLOTHING.

Soul trade:
- accepted deal gives player **+1 Strength**;
- subtracts **10 from maximum Health**;
- third accepted deal in total before death => player death for now; refusal does not reset the count (owner clarification 2026-10-12);
- persist deal count/state;
- all mutations go through the authoritative player stats/Health contracts, not UI/dialogue direct field hacks.

Future ending hooks should have a clean event/state boundary.

### Жуткий
Stalks behind the player and asks unsettling questions, especially during terminal parcel
issuing. Avoids direct visibility until noticed, then may resume normal fallback according
to traits/memory. Use perception and authored approach positions; no teleporting behind player.

### Вампир
Prefers wounded-player feeding attacks, stopping before ordinary lethal damage through an
authored health floor/stop condition rather than exact-HP comparisons. Dislikes light without
unconditional flight. Perceived Blood Hazard immediately calms it and attracts/retains it
while valid. May request **5–40% of current HP** by consent, become invisible or escape as a
cloud when threatened. Receiver tags implement blood/holy/unholy behavior.

## Order preference contract

NPC ordering must use item category/tag weights, not specific item IDs.

Examples:
- clothing-heavy archetypes continue working even when new clothing items are added;
- reagent-heavy archetypes automatically see future reagents;
- “anything” means weighted selection from all currently orderable catalog categories.

Missing categories/items must degrade gracefully instead of generating invalid orders.

## Trait composition acceptance

- New archetype can be authored without editing a central NPC-type `match`.
- New trait can be attached to multiple archetypes.
- Incompatible traits are rejected before spawn.
- Rolled traits and dialogue variant persist through save/load.
- New-game district records from existing authored profiles receive deterministic valid data.
  Unsupported pre-R26 saves reject before mutation and remain protected; no save conversion.
- Traits do not become another gameplay-state authority parallel to GECS/Relationships.
