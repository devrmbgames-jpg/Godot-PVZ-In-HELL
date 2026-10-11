# R26.2 — NPC archetypes, composable traits and persistent variation
Status: **IN_PROGRESS**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Replace “one fixed profile == one fixed NPC personality” with a data-driven model:

**base archetype + mandatory traits + compatible optional traits + persistent per-person variation.**

The system must make it easy to create later NPC combinations not explicitly anticipated today.

### Current

Started after reviewed physical-catalog checkpoint `b89a21f4bdf0daf0609595dc3adc502bd5424535`.
DEF_NpcArchetype extends existing physical/social Profile tuning; inherited rules are mandatory.
Authored name/dialogue pools, weighted optional traits, stable-key incompatibility, receiver tags,
combat/category/presentation data and bounded personality modifiers have typed definitions.
NpcVariationRules creates detached choices using DecisionRandomRules and sorts weighted candidates by key.
NpcVariation stores canonical creation seed/day, selected name/dialogue/optional keys and modifiers;
the closed codec preserves values and rejects missing/extra fields without rerolling.
Ten native DEF_NpcArchetype .tres assets now provide all required placeholder name pairs,
category preferences, receiver/damage data, existing reusable rules and optional weighted pools.
Schedule/trait Resources are editor-instantiable; all new assets were saved through native MCP.
These are authored inputs, not live roster integration or complete mandatory behavior acceptance.
Next: migrate initial/replacement population and compiler consumers to durable variation;
bind the native ten-archetype inputs, compose receiver tags, version the changed snapshot contract
and verify fresh/reused restore without reroll. Finish migration before marking this task DONE.

### Validation

Foundation parser200116353 7/7; GUT200129137 6/6,360 PASS (2026-10-11 native logs under
`.artifacts/godot_agent/`). Checks cover repeatability, pool order, compatible bounded choices,
weight influence, distinct seeds/names, malformed definitions/choices and exact codec roundtrip.
GUT200240843 save-data regression PASS; formatter and strict architecture/domain/project checks PASS.
Initial parser failed because `trait` is reserved in Godot 4.7.1; renamed fields/locals to `rule`,
preserving log195946517. Public pure seed/codec edges were declared before strict checks passed.
MCP scan and fresh test diagnostics checked[] PASS; loaded global script reload43 remains NOT_PASS;
fresh native parser/GUT PASS independently. No scene/resource external rewrites or rendered gameplay.
Foundation review BASE b89a21f4bdf0daf0609595dc3adc502bd5424535 ->
TARGET 473e1569425d9c6bcd809828c3c8422e6280b66f PASS; no material findings (69 s).
Native catalog parser201559767 3/3 and final GUT201925750 4/4,944 PASS: all ten assets load,
generate and roundtrip deterministic variations, preserve shared inputs, and carry required names,
existing capability/category and intrinsic immunity/receiver contracts. MCP test diagnostics checked[].
Initial catalog parser201538629 failed on nested PackedStringArray constant; fixed to literal arrays.
Catalog review BASE 473e1569425d9c6bcd809828c3c8422e6280b66f ->
TARGET ca6bc069c5645028fd9b51e681d9364291e6f32c found RV-001 (70 s), STYLE PASS.
RV-001 / R1 P2: angel receiver_traits=0 excluded it from holy artifacts before resistance.
Accepted: native MCP repair sets HOLY_VULNERABLE; regression now exercises actual
ReceiverEffectRules HOLY DAMAGE / UNHOLY EXCLUDED. Fix committed next; targeted review pending.
NOT_RUN: roster/receiver integration, full persistence migration,
new mandatory behaviors (angel observation/signs, grudges, toy witnessing, 10 m floor fire/opening,
soul trade, stalking, vampire feeding/escape), presentation hooks, gameplay and owner acceptance.

### Owner QA / blockers

Subjective gameplay, dialogue, assets and balance require owner QA after implementation.
Required owner acceptance remains open; explicitly deferred polish gets a QA checklist.

## Required data model

Prefer authored Resources instead of hard-coded type switches.

Introduce/extend a base archetype definition containing:
- archetype key/display label;
- base physical scene/appearance reference;
- two or more placeholder name variants;
- mandatory traits;
- optional weighted trait pool;
- incompatible trait rules;
- base personality/social tuning;
- item order category weights;
- dialogue variant paths/keys;
- combat preference (melee/ranged/avoid);
- receiver/species tags needed by holy/unholy/blood/fire rules;
- archetype-specific presentation hooks as data, not direct UI/audio ownership.

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

- Скромник: **Тихон**, **Мирон**
- Плачущий ангел: **Сераф**, **Азариэль**
- Ночной охотник: **Морок**, **Нокт**
- Карга: **Морана**, **Аграфена**
- Бугай: **Гром**, **Бран**
- Огненный элементаль: **Пирос**, **Углик**
- Потерянный: **Лука**, **Ян**
- Цепной дьявол: **Азгар**, **Мальх**
- Жуткий: **Шорох**, **Хрип**
- Вампир: **Северин**, **Владен**

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
- three consecutive accepted deals => player death for now;
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
