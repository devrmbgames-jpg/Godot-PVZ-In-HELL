# R26.2 — NPC archetypes, composable traits and persistent variation
Status: **PLANNED**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Replace “one fixed profile == one fixed NPC personality” with a data-driven model:

**base archetype + mandatory traits + compatible optional traits + persistent per-person variation.**

The system must make it easy to create later NPC combinations not explicitly anticipated today.

### Current

PLANNED; no R26 implementation or acceptance is claimed. Apply the current contracts
in [R26](r26_items_npc_expansion.md#existing-contracts-to-preserve) when this milestone starts.
The 2026-10-10 audit updates specification only.

### Validation

NOT_RUN: R26 engine/gameplay checks. Follow the acceptance and validation sections below,
[validation-workflow](../.agents/skills/validation-workflow/SKILL.md) and the root review gate.

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
