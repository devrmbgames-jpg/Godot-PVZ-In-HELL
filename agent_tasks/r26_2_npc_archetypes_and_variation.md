# R26.2 — NPC archetypes, composable traits and persistent variation
Status: **PLANNED**

Parent: `agent_tasks/r26_items_npc_expansion.md`

## Goal

Replace “one fixed profile == one fixed NPC personality” with a data-driven model:

**base archetype + mandatory traits + compatible optional traits + persistent per-person variation.**

The system must make it easy to create later NPC combinations not explicitly anticipated today.

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
Mandatory:
- dislikes direct gaze;
- likes observing others while trying not to be observed;
- sustained player stare escalates to aggression;
- order preference heavily weighted to CLOTHING.

Optional variation examples:
- patience before aggression;
- preferred observation distance;
- timid vs resentful social response.

### Плачущий ангел
Mandatory:
- can move only while player is not looking at it;
- only HOLY damage can meaningfully hurt it;
- other NPCs should strongly avoid voluntary conflict with it;
- cannot hold normal spoken dialogue; communicates with signs/boards;
- order preference: ARTIFACT;
- when aggressive, attack/movement are still possible only while unobserved;
- aggressive movement speed is several times the peaceful value, authored as tuning.

Do not implement “looked at” as omniscient bool; use real player camera/frustum/line-of-sight contract.

### Ночной охотник
Mandatory:
- dark -> aggressive attack behavior;
- light -> peaceful/flee behavior;
- always retreats from sufficiently bright zones;
- appearance warning presentation: music change + denser shadow presentation;
- order preference: WEAPON + CLOTHING.

Presentation warning must not own AI state.

### Карга
Mandatory:
- deceptive dialogue tendencies;
- riddles;
- grudge/long memory affects later reactions;
- ranged combat preference;
- order preference: REAGENT + ARTIFACT.

### Бугай
Mandatory:
- respects demonstrated strength;
- dislikes weakness;
- threatening dialogue tone;
- order preference: WEAPON;
- low-probability TOY order;
- prefers private booth when unpacking;
- if player visibly witnesses it holding/unpacking a toy, immediately escalates to attack.

The toy trigger must use actual perception/visibility, not global knowledge.

### Огненный элементаль
Mandatory:
- fire immune;
- fire aura;
- thin floor Hazard around it with authored radius default **10 m**;
- floor effect should force/encourage player to get off the floor through real Hazard rules, not scripted teleport;
- order preference strongly weighted to fire REAGENT;
- often opens parcels immediately;
- authored chance that relevant parcel contents explode while held/opened.

Do not create duplicate custom fire damage authority; reuse hazard/damage systems.

### Потерянный
Mandatory:
- neutral baseline;
- medium aggression;
- no strong supernatural rule required;
- can order any available category.

This is the control/baseline archetype for generic behavior.

### Цепной дьявол
Mandatory:
- repeatedly offers soul trade in appropriate dialogue;
- easy to anger;
- fire immune;
- order preference: WEAPON + ARTIFACT, sometimes CLOTHING.

Soul trade:
- accepted deal gives player **+1 Strength**;
- subtracts **10 from maximum Health**;
- three consecutive accepted deals => player death for now;
- persist deal count/state;
- all mutations go through the authoritative player stats/Health contracts, not UI/dialogue direct field hacks.

Future ending hooks should have a clean event/state boundary.

### Жуткий
Mandatory:
- stalks behind player;
- asks unsettling questions;
- especially likes approaching behind player while player is using the terminal during parcel issuing;
- before being noticed, tries to stay outside direct player visibility;
- once noticed, normal fallback behavior may resume according to traits/memory.

Use perception and authored approach positions; do not teleport behind the player.

### Вампир
Mandatory:
- prefers attacking wounded player but intentionally avoids killing them in ordinary feeding aggression;
- dislikes light but is not forced to flee solely from light;
- Blood Hazard immediately calms it;
- if it perceives a Blood Hazard, prefers to enter/remain in that zone while valid;
- may ask to drink player blood, removing authored **5–40% of current HP** on accepted interaction;
- may become invisible;
- may turn into a cloud and escape when threatened;
- receiver tags make it react correctly to blood and unholy/holy rules.

“Do not finish wounded player” requires an authored health floor/stop condition, not brittle exact-HP comparisons.

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
- Existing district people migrate/retain deterministic valid data.
- Traits do not become another gameplay-state authority parallel to GECS/Relationships.
