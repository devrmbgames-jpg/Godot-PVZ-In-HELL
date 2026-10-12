# R26.4 — Two dialogue variants per NPC archetype
Status: **IN_PROGRESS**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Create **two independent dialogue variants for every requested NPC archetype** using the existing Dialogue Manager integration.

The owner will later copy these resources and add more variants. Therefore paths/data must make adding a third/fourth variant trivial without changing code.

### Current

Native lost/shy/night/angel/hag catalogs now expose **10/20** variants. Committed per-person selection survives codec/save; explicit visit resources retain priority. All variants preserve imported role cues, registered-number guards, denial/private delivery authority, response tags and imported-cycle cleanup.
Shy variants read gaze warnings; night variants read authored perceived darkness; angel variants use native written boards. Hag variants differ in deception, reagents/artifacts and riddles (name versus hole), read personal grudges and keep street answers separate from idempotent service outcomes.
Hag checkpoint `6293c6bdb34334832f0c02e720df11c75cc20dd2` passed independent review. Remaining five archetypes need their mandatory behaviors/interactions and ten variants before live roster binding.

### Next

Brute behavior `b72342b7ab3c08fdd49fa1b9c9ebb55ced9a80b5` passed implementation checks and independent review; author its two threatening variants. Finish remaining fire/chain/creepy/vampire interactions. Soul/blood transactions and full owner acceptance remain open.

### Validation

Hag PASS: parser022034711/1; native GUT021925998 **38/966** including inherited31, all role cues, saved selection, read-only grudge tone, correct/wrong retries, solved-but-unregistered guard, denial, four private deliveries and actual headless modal panels with response/focus release.
MCP authored/imported both variants, saved exactly one catalog-pool line with UID/tuning retained and refreshed cache; fresh test diagnostics checked[] PASS. Formatter incremental/strict, architecture/project/persistence/staged/diff PASS. No extra full smoke for this authored-dialogue batch; native role/panel tests cover its scope.
Hag review BASE `9c70cd2c684994a907e35cd74fd01b9bc30e20e7` -> TARGET `6293c6bdb34334832f0c02e720df11c75cc20dd2` PASS, no findings (119 s); ARCHITECTURE/STYLE PASS, reviewer runtime NOT_RUN.
Earlier native PASS: lost225318292 **31/621** + service224919731; shy233416121 **35/759**; night001711308 **37/831**; angel011214901 **38/889** + service011255565 **15/272**. Logs under `.artifacts/godot_agent/gut-202610{11,12}-<timestamp>.{stdout,stderr}.log`; unique parser/MCP/static evidence remains in Git checkpoints.
Shy reviewed `5ff85b58ea107ec795d3dea4319be9dcf10306b1` -> `b1b9c38f8844723850a5223d6f4c4271f5ef7ef7` PASS (61 s).
Night reviewed `b798cfb4817c6d4e05f01a52a66695a9e82b3c71` -> `66813497b64120f26626b1ca2694207dc7cad146` PASS (17 s).
Angel reviewed `e905f5ea0809dafbb2008d52f4b8283af43dbb2c` -> `373dc4a1f64ad3f4f57cf8c322cea6bb77158cbb` PASS (45 s).
Global hot reload43 remains NOT_PASS; actual layouts/restart and fresh CLI checks independently verify saves. Full 20-variant acceptance and rendered/tone/modal owner QA NOT_RUN.

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
