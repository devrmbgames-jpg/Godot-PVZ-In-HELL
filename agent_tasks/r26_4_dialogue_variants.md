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
The native lost archetype exposes both paths; only **2/20** variants are implemented.
Review of `490efacd2b5888383325bdbf37aa13b3753be4a4` against
`1bb1f2a02cfc92ee247c3b1bf34028aedd0b3d63` found the missing direct registration guard.
The guard is restored in both variants, with focused native regression PASS; targeted repair
review remains REVIEW_PENDING.
Remaining archetypes still need their required interactions, including authoritative soul/blood
transactions; full task acceptance and live roster binding remain open.

### Next

Collect immutable-SHA review, then continue required archetype behavior/interaction capabilities
and author the remaining 18 variants. No per-open reroll or new UI authority is introduced.

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

### Review triage

RV-001 — ACCEPTED P1, source `490efacd2b5888383325bdbf37aa13b3753be4a4`:
both personalized `direct` cues omitted `ctx.has_registered_number()`, exposing denial before
registration. Restored the existing guard and scanning/END fallback. Focused real-context
regression checks repeated unregistered entry without choices, denial/reputation/aggression
mutation and preserves registered denial/idempotency. Fix SHA/targeted review pending.
Initial reviewer ARCHITECTURE FAIL / STYLE PASS / runtime VALIDATION NOT_RUN (78 s).

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
