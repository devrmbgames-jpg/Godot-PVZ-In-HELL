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
Schema 14 rejects incomplete/unsupported records before mutation; restore never rerolls.
Next: finish review of the integration checkpoint, bind all ten archetypes, category ordering,
presentation/combat preferences and mandatory behaviors with R26.3/R26.4. Acceptance stays open.

### Validation

Native Godot 4.7.1 logs are under `.artifacts/godot_agent/` (2026-10-11 UTC).
Foundation parser200116353 7/7, variation GUT200129137 6/6,360 and save-data200240843 PASS;
catalog parser201559767 3/3, final GUT201925750 4/4,944 PASS. These prove bounded compatible
deterministic choices, shared isolation, exact codec, all ten native assets/names/categories/tags.
Foundation review BASE b89a21f4bdf0daf0609595dc3adc502bd5424535 ->
TARGET 473e1569425d9c6bcd809828c3c8422e6280b66f PASS, no findings (69 s).
Catalog review TARGET ca6bc069c5645028fd9b51e681d9364291e6f32c (70 s) found RV-001/R1 P2:
angel lacked holy eligibility. FIXED a02e250b80a4b984e662854452f8cc110e356660;
actual HOLY DAMAGE/UNHOLY EXCLUDED regression and targeted review PASS (8 s).
Cache tool review BASE a02e250b80a4b984e662854452f8cc110e356660 ->
TARGET 589cadfdca1b61006510338a5f88d94ec5ec8e9e (38 s) found RV-002/R1 P1:
inspected ::subresources lacked file-owner protection. FIXED
fd2627ee7e6312efbc6c5a9afb70b77fa997ce1f; parser203852011/GUT203819728 3/3,35,
live MCP diagnostics and targeted review PASS (2 s). No file/UID changes during cache refresh.
Both repairs have ARCHITECTURE/STYLE PASS; reviewer runtime checks NOT_RUN.
Integration: factory GUT205245545 13/13,102; world snapshot205034739 33/33,407;
shared host205140832 2/2,260; doctor205354140 20/20,119; preview205302600 10/10,66;
compiler205515135 33/33,189; recipe isolation205524795 7/7,42; perception205530362 8/8,27;
blood205538943 10/10,120; community205551797 15/15,99; randomness205614732 11/11,103;
save-data205633042 6/6,40; district plan205648020 41/41,260 PASS.
District snapshot210427837: 15/15,169 tests PASS, no runtime errors/orphan Nodes;
runner FAIL solely on shutdown Resource/RID/VariantPools retention: KNOWN_ENGINE_LIMITATION/DEFERRED.
New checks cover selected optional fire, receiver composition, fresh/reused variation restore,
missing/extra/invalid choices, replacement retry persistence and rejection before live mutation.
Style and strict architecture/domain/project checks PASS. MCP test diagnostics checked[] PASS;
global reload43 remains NOT_PASS; native CLI verifies separately. Clean game_world reloaded via MCP.
Parser210253264: all 37 individual compilations PASS; aggregate runner FAIL on the snapshot test's
shutdown retention above. Cache policy extension parser210707631 2/2/GUT210631184 4/4,52 PASS;
MCP refresh updates both exact identity policies in place and preserves references/files/UIDs.
Week smoke PASS: tests/artifacts/district-20261012-065857869.log. Integration review pending.
NOT_RUN: ten-archetype roster binding, category ordering, new mandatory behaviors,
presentation hooks, rendered gameplay and owner acceptance. No external scene/resource rewrites.

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
