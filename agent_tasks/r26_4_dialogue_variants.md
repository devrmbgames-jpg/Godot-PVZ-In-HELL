# R26.4 — Two dialogue variants per NPC archetype
Status: **IN_PROGRESS**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Create **two independent dialogue variants for every requested NPC archetype** using the existing Dialogue Manager integration.

The owner will later copy these resources and add more variants. Therefore paths/data must make adding a third/fourth variant trivial without changing code.

### Current

The street/customer router reads the committed per-person variant; an explicit visit resource
keeps priority and legacy actors keep their role fallback. Two neutral/lost variants now have
distinct greetings, neighborhood and broad shopping topics plus all existing role entry cues.
Pinned Dialogue Manager imports preserve service outcomes, personal delivery and response tags;
session cleanup releases cached imported line cycles as well as the root resource.
The native lost, shy, night and angel archetypes expose both paths; **8/20** variants are implemented.
Shy variants distinguish withdrawn fear from resentful avoidance and read the committed
gaze warning through a query adapter shared by street/customer contexts. Reading dialogue
does not advance exposure or alter memory. Both keep the registration guard and role imports.
Night variants use restrained warning versus playful predatory tones, weapon/clothing topics
and light advice. Both roles read the same authored perceived-light predicate as the native
hunt guard. Dialogue performs no sensing or aggression mutation; registration guards and
existing denial/private delivery owners remain intact. Night checkpoint review passed.
Review of `490efacd2b5888383325bdbf37aa13b3753be4a4` against
`1bb1f2a02cfc92ee247c3b1bf34028aedd0b3d63` found the missing direct registration guard.
The guard is restored in both variants, with focused native regression PASS. Targeted repair
review of `c64c5f782ee1874c0e987b34064b132cb6a7c5e5` passed without remaining findings.
Shy dialogue review BASE `5ff85b58ea107ec795d3dea4319be9dcf10306b1` ->
TARGET `b1b9c38f8844723850a5223d6f4c4271f5ef7ef7` PASS, no findings (61 s).
Reviewer ARCHITECTURE/STYLE PASS; runtime VALIDATION NOT_RUN.
Angel variants use terse instructions versus religious signs. Both roles render every line through
an authored native board, retaining existing response tags, modal capture and gameplay context.
The sign cue is immutable profile data, with ordinary actors retaining speaker/text presentation.
Native pool authoring preserves all tuning/UIDs and changes only the two variant paths.
Angel checkpoint review is pending. Remaining archetypes need interactions, including soul/blood
transactions; full task acceptance and live roster binding remain open.

### Next

Continue required archetype behavior/interaction capabilities
and author the remaining 12 variants after the angel checkpoint review.
No per-open reroll or new UI authority is introduced.

### Validation

- PASS: native parser for six edited GDScripts; incremental GDQuest style, strict architecture,
  domain dependencies/structure, project structure, persistence baseline and diff checks.
- PASS: `test_npc_dialogue_variants.gd` **31/31, 621 assertions**, including inherited district
  regressions, native imported cues, stable codec restoration, both real contexts and actual
  panel routing, delivery acceptance/idempotency, denial tags/idempotency and imported cleanup.
  Logs: `.artifacts/godot_agent/gut-20261011-225318292.{stdout,stderr}.log`.
- PASS: existing `test_customer_dialogue.gd`; logs
  `.artifacts/godot_agent/gut-20261011-224919731.{stdout,stderr}.log`.
- MCP: native authored lost catalog save/cache refresh and settled import/inspection of both
  variants ran. Global-script hot reload returns fallback code 43 (NOT_PASS); fresh CLI checks
  independently pass. No rendered gameplay/visual QA ran.
- NOT_RUN: full 20-variant acceptance, remaining archetype interactions and owner dialogue QA.
- Shy PASS: parser233406749/3 and `test_npc_shy_dialogue.gd` **35/35, 759 assertions**,
  including inherited role/routing/delivery regressions, both native variants, warning reads,
  repeated unregistered entry and registered denial/idempotency. Logs:
  `.artifacts/godot_agent/gut-20261011-233416121.{stdout,stderr}.log`; no runtime errors.
  Formatter/lint, strict architecture/dependencies, domain/project structure and persistence PASS.
  MCP native catalog save, settled imports, test reload/diagnostics and clean scene reload PASS;
  no new editor errors after repair. Global-script reload43 NOT_PASS; CLI independently PASS.
- Night PASS: parser001701989/5; `test_npc_night_dialogue.gd` **37/37, 831 assertions**,
  actual imported role cues, codec selection, both light tones/hidden-player/threshold reads,
  unregistered guard, registered denial/idempotency and four private-delivery acceptances.
  Logs `.artifacts/godot_agent/gut-20261012-001711308.{stdout,stderr}.log`; no runtime errors.
  Formatter/lint, strict architecture/dependencies, domain/project structure and persistence PASS.
  MCP saved the native catalog preserving UID and tuning, imported both dialogues and reloaded
  the clean scene; test/leaf diagnostics PASS, global hot reload43 NOT_PASS, CLI independently PASS.
  Review `b798cfb4817c6d4e05f01a52a66695a9e82b3c71` ->
  `66813497b64120f26626b1ca2694207dc7cad146` PASS, no findings (17 s);
  ARCHITECTURE/STYLE PASS, reviewer runtime VALIDATION NOT_RUN. Rendered/dialogue feel: NOT_RUN.
- Angel PASS: parser011202524/7, native GUT011214901 **38/889**; service011255565 **15/272**.
  Tests include actual native boards, ordinary presentation, focus/mouse capture/release,
  imported role cues, committed codec, registration/denial idempotency and four private deliveries.
  Companion pool preflight GUT010415794 4/28 PASS; native catalog diff is exactly one pool line.
  Formatter/lint, strict architecture/dependencies, domain/project structure and persistence PASS.
  MCP authored scene/style/pool/imports; test diagnostics checked[] PASS. Global reload43 NOT_PASS;
  clean restart and CLI independently verify current source. Review REVIEW_PENDING; owner visual QA NOT_RUN.

### Review triage

RV-001 — FIXED P1, source `490efacd2b5888383325bdbf37aa13b3753be4a4`:
both personalized `direct` cues omitted `ctx.has_registered_number()`, exposing denial before
registration. Restored the existing guard and scanning/END fallback. Focused real-context
regression checks repeated unregistered entry without choices, denial/reputation/aggression
mutation and preserves registered denial/idempotency. Fix
`c64c5f782ee1874c0e987b34064b132cb6a7c5e5`, GUT31/621 PASS. Targeted reviewer
ARCHITECTURE/STYLE PASS, no remaining findings (5 s); runtime VALIDATION NOT_RUN.

### Owner QA / blockers

Subjective gameplay, dialogue, assets and balance require owner QA after implementation.
Required owner acceptance remains open; explicitly deferred polish gets a QA checklist.

## Authoring structure

Prefer separate dialogue resources per variant, grouped by archetype, e.g.:

```text
content/domains/npc/dialogue/archetypes/<archetype>/
  variant_a.dialogue
  variant_b.dialogue
```

Extend the existing NPC dialogue owner at `content/domains/npc/dialogue/` and its domain
service/context adapters. The archetype definition exposes available dialogue variants.
`NpcRecord` stores the selected variant for persistent identity.

Use [dialogue-systems](../.agents/skills/dialogue-systems/SKILL.md) and
[Dialogue Manager v4.1](../.agents/skills/dialogue-manager-v4.1/SKILL.md) for resource APIs,
cues/mutations and response tags. Stable communication UI is an editable `.tscn`; use
editor/MCP for open assets. Existing `content/ui/` adapters retain their ownership.

Do not choose a random dialogue resource every time the same NPC opens dialogue.

Both variants must implement the same required gameplay contracts but use clearly different wording/personality expression.

Do not make Dialogue Manager the authority for combat, inventory, Health, Strength, karma, soul-deal count, parcel state or social memory. Dialogue calls narrow context/service actions.

## Placeholder identity mapping

- Скромник: Тихон / Мирон
- Плачущий ангел: Сераф / Азариэль
- Ночной охотник: Морок / Нокт
- Карга: Морана / Аграфена
- Бугай: Гром / Бран
- Огненный элементаль: Пирос / Углик
- Потерянный: Лука / Ян
- Цепной дьявол: Азгар / Мальх
- Жуткий: Шорох / Хрип
- Вампир: Северин / Владен

Names and prose are placeholders; structure and gameplay hooks are the important deliverable.

## Required dialogue intent by archetype

### Скромник
Two variants must:
- dislike direct staring;
- become increasingly uncomfortable/threatening if player keeps staring;
- optionally mention clothing/interests/orders;
- support existing lie/convince/etc response-tag analytics/debug prefix conventions where applicable.

Variant A: withdrawn/polite fear.
Variant B: resentful/irritable avoidance.

### Плачущий ангел
No normal spoken conversation.

Implement two **sign/board communication variants** using the dialogue pipeline or a narrow presentation adapter:
- Variant A: terse warning/instruction signs.
- Variant B: cryptic/religious signs.

It must remain mechanically a dialogue interaction where useful, but presentation is written/sign-based, not spoken lips/dialogue.

### Ночной охотник
Two variants:
- warn or hint about darkness/light;
- peaceful restrained tone while safe/light;
- threatening predatory tone where current perceived state allows;
- weapon/clothing order flavor.

A dialogue line must not directly toggle aggression; AI state derives from actual light/perception.

### Карга
Two variants:
- deception/ambiguous answers;
- at least one riddle interaction path each;
- different lie/riddle style;
- reagent/artifact order flavor;
- grudge-compatible responses.

### Бугай
Two variants:
- constant threatening/bragging tone;
- strength/respect choices;
- weapon order flavor;
- rare toy topic must be evasive/embarrassed, but the **actual witnessed toy attack trigger is perception gameplay**, not dialogue.

### Огненный элементаль
Two variants:
- fire/reagent obsession;
- comments around heat/explosive parcel opening;
- distinct personality tones despite same mechanical archetype.

Do not roll explosion chance from dialogue.

### Потерянный
Two broad neutral variants:
- ordinary resident/customer;
- can discuss/order anything;
- serve as baseline dialogue templates for future generic NPCs.

### Цепной дьявол
Two variants must include soul-sale offer.

Accepted soul deal calls a narrow gameplay service that:
- +1 Strength;
- -10 max Health;
- increments persistent consecutive accepted-deal count;
- third consecutive accepted deal causes death for now.

Variant A: contractual/legalistic.
Variant B: mocking/tempting.

Decline/cancel paths must not accidentally apply the deal.

Soul/blood acceptance submits one typed operation with a stable confirmation key and an
observable committed result. Reopening a line, retrying a callback or restoring a save
must not apply it again. Max-Health/Strength changes use a declared authoritative transaction;
HP damage/healing and death still follow the common combat/lifecycle boundary.

### Жуткий
Two variants:
- unsettling questions;
- acknowledge unexpected proximity/being noticed;
- one more quiet/creepy, one more invasive/playful-horror;
- no teleport/stalking authority in dialogue.

### Вампир
Two variants:
- may ask permission to drink blood;
- accepted amount is authored/randomized within **5–40% of current HP** through a gameplay service;
- dialogue communicates the consequence before confirmation;
- refusal does not apply damage;
- blood/hunger flavor differs strongly between variants.

Vampire blood request uses current HP, not max HP, and must not bypass the common damage contract.

## Shared dialogue requirements

- Existing response tags such as lie/convince/etc keep their debug prefixes.
- Dialogue conditions read context; they do not duplicate long AI conditions if those already have authoritative services.
- Distinguish actual line/branch outcome from perceived/presentation text where the existing adapter already does so.
- Persistent personal memory may affect available tone/branches.
- No hard-coded player/NPC scene paths in dialogue scripts.
- Copying a variant resource and adding its path to authored data is sufficient to expand variety.

## Acceptance

- 20 initial dialogue/sign variants exist: 2 × 10 archetypes.
- Same person retains its selected variant across save/load.
- Each variant has at least one recognizable archetype-specific branch beyond generic greeting/service.
- Soul/blood interactions are idempotent and authoritative gameplay effects.
- Angel uses signs instead of full spoken conversation.
- Dialogue parser/import passes with no broken cues/titles.
