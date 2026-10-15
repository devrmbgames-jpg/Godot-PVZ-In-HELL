# R26.4 — Two dialogue variants per NPC archetype
Status: **DONE** — принято владельцем 2026-10-15.

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Create **two independent dialogue variants for every requested NPC archetype** using the existing Dialogue Manager integration.

The owner will later copy these resources and add more variants. Therefore paths/data must make adding a third/fourth variant trivial without changing code.

### Current

**Завершено: владелец принял результат 2026-10-15.** Новые замечания и запланированные доработки сохраняют собственный незавершённый статус.

Техническая контрольная точка до ручной приёмки; прежние пометки ожидания OWNER_QA ниже закрыты решением владельца:

All ten native archetype catalogs expose **20/20** variants. Committed personal selection survives
codec/save; visit overrides retain priority. Every variant preserves role cues, scan guards,
denial/private delivery authority, response tags and imported-cycle cleanup. Historical archetype
flavor/interaction evidence remains in Git; required individual intent is specified below.
Vampire variants differ in restraint/direct hunger. Shared confirmation captures current-HP terms,
explicit acceptance/refusal, durable closure/replay and actual street/service panel responses.
All ten archetypes now enter the production roster in R26.5 migration
`81f22ee6e09a3466237ac67564554052fc4a2634`; immutable review PASS, no findings.
Real selected dialogue paths/variations and native reconstruction pass live-roster GUT10/798.
Final automated integration/week and immutable review PASS in R26.5; owner acceptance remains open.

### Next

Задача закрыта и архивирована. Возобновление этой реализации не требуется; обнаруженные впоследствии дефекты оформляются отдельными задачами.

Последняя техническая контрольная точка из прежнего Next (до приёмки владельцем):
Vampire review collected on BASE `a407762ef018ab70715119cd432c63071d62d928` ->
TARGET `14cadff37461590c14454aabfdbca1fb4af11e94` **PASS** (50s, no material findings); same terminal reviewer
reused, no second reviewer. Next: complete owner dialogue/tone/modal acceptance; R26.5 automated integration is PASS.

### Validation

Post-R27 native suites cover both variants of all ten archetypes; current totals/manifest
owned by [R26.5](r26_5_integration_persistence_validation.md). Rendered tone/presentation QA remains open.


Vampire checkpoint `14cadff37461590c14454aabfdbca1fb4af11e94`: native GUT190739486
**39/1069**, Chain common-context regression190855067 **39/945**, parser1907427702/2 PASS.
Both roles and variants preserve percentage from offer, actual acceptance-time HP, limits/Strength,
nonlethal cost, terminal replay/refusal and pending codec restore. Real panels confirm/refuse and
release modal focus; role cues/tags, scan/denial/private delivery and selection PASS. Native MCP
import/ResourceSaver retains profile UID/tuning; final new test diagnostics checked[]. Formatter/lint,
strict architecture/dependencies, project/persistence/staged/diff PASS. Full20 live QA stays open.

Earlier variant checks/reviews remain in their task snapshots. Latest Creepy
`ad79c0eab6a00772dd578a3a7d25053166db70ef` GUT36/1009, parser3files, immutable review
PASS on BASE `23fa3d44d9024d4becb59477921be1d288d7bee9`, no material findings.
Global hot reload43 remains NOT_PASS; native path diagnostics and CLI independently verify saves.
All20 variants have native branch coverage; rendered/tone/modal owner QA remains NOT_RUN.

### Review triage

RV-001 — FIXED P1, source `490efacd2b5888383325bdbf37aa13b3753be4a4`:
both personalized `direct` cues omitted `ctx.has_registered_number()`, exposing denial before
registration. Restored the existing guard and scanning/END fallback. Focused real-context
regression checks repeated unregistered entry without choices, denial/reputation/aggression
mutation and preserves registered denial/idempotency. Fix
`c64c5f782ee1874c0e987b34064b132cb6a7c5e5`, GUT31/621 PASS. Targeted reviewer
ARCHITECTURE/STYLE PASS, no remaining findings (5 s); runtime VALIDATION NOT_RUN.

### Owner QA / blockers

Принято владельцем 2026-10-15 по сообщению «Закрой все задачи где OWNER_QA». Ранее реализованный объём закрыт общей приёмкой; новые замечания остаются отдельными задачами. Поштучный прогон всех сценариев и новая визуальная QA агентом не заявляются.

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

Use [dialogue-systems](../../skills/dialogue-systems/SKILL.md) and
[Dialogue Manager v4.1](../../skills/dialogue-manager-v4.1/SKILL.md) for resource APIs,
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

| Archetype | Required shared intent and variant distinction |
| --- | --- |
| Скромник | Dislikes staring, escalating discomfort/threats; clothing/interests/orders and lie/convince tags. A withdrawn/polite fear, B resentful/irritable avoidance. |
| Плачущий ангел | A terse warnings/instructions, B cryptic/religious signs. Owner R27 supersedes dialog presentation: real3D board/Label3D in front of NPC, no normal spoken/modal dialogue. |
| Ночной охотник | Darkness/light hints, restrained safe/light tone versus perceived predatory threat; weapon/clothing flavor. Dialogue never toggles aggression directly. |
| Карга | Both have distinct deception/ambiguous answers and a riddle path, reagent/artifact flavor and grudge-compatible replies. |
| Бугай | Threatening/bragging strength/respect choices, weapon flavor; evasive/embarrassed rare toy topic. Actual witnessed toy attack remains perception gameplay. |
| Огненный элементаль | Distinct fire/reagent obsession and heat/explosive-opening flavor; dialogue never rolls explosions. |
| Потерянный | Two neutral ordinary resident/customer templates; unrestricted topics/orders suitable for future variants. |
| Цепной дьявол | Both offer soul sale: A contractual/legalistic, B mocking/tempting. Refusal/cancel never commits a deal. |
| Жуткий | Unsettling questions and recognition of proximity/being noticed; A quieter/creepy, B invasive/playful horror. No teleport/stalking authority in dialogue. |
| Вампир | Distinct blood/hunger tones; asks explicit consent and shows cost before confirmation. Refusal never damages HP. |

Accepted soul deal uses the owning service: +1 Strength, -10 max Health and durable accepted-deal
count increment before death. Third total accepted deal kills; refusal never resets the count
(owner clarification2026-10-12). Vampire consent costs authored/randomized5–40% of current HP,
never max HP, through the common damage contract.
Soul/blood acceptance is one typed transaction with stable confirmation key and committed result;
reopening, callback retries or restore cannot replay it. Max-Health/Strength have their declared
transaction owner; HP/healing/death retain common combat/lifecycle ownership.

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
