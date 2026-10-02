# R23 — Полный вертикальный срез

Status: **OWNER_QA**

## Task state

### Goal
Пройти законченный день до следующего утра без debug-команд и ручной перезагрузки сцены.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R01, R02, R03, R04, R05, R06, R06.1, R07, R08, R09, R10, R11, R11.1, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22, R22.5
- Reuse existing authoritative contracts from completed dependencies; do not duplicate them.
- The existing `## Работы`, `## Критерии готовности`, `## Проверки`, and `## Границы` sections remain the detailed implementation specification.
- Follow Godot 4.7, GECS ownership, physics authority, and validation rules from `AGENTS.md`.
- Общий игровой контракт владельца: `MeshInstance3D.material_overlay` предназначен только для интерактивной обратной связи и выделений; материалы выделения — внешние редактируемые ресурсы (QA-13).

### Milestones
- [x] Reconfirm dependency implementation and current production owners/contracts; owner QA remains in dependencies.
- [x] M1: fixed authored supply/customer families and scenario route/feedback audit.
- [x] QA batch A implementation: Windows export, direct player view, seam adhesion/jump guard, living grab guard and Trader interaction; player acceptance pending.
- [x] QA-11: native NPC avoidance, stationary/queue/corridor/reset regressions; Navigation cell_size 0.25 on main/test. Player acceptance pending.
- [x] Updated owner scope QA-14–QA-20 implementation (owner acceptance pending): CharacterBody player/archive/immersive slots, refusal after handoff, Terminal debug-only truth, liquid alignment, immediate gaze and light-client entrance effects, knife/hammer animation.
- [x] Owner QA batch implementation and scoped automated verification (manual enlarged-scene acceptance pending): [QA-01–QA-13](roadmap_23_vertical_slice_validation/owner_qa.md) on the enlarged main scene.
- [ ] M2: ordinary-input Morning → Day → Evening → Night → Morning walkthrough.
- [ ] M3: alternative outcomes/combat/carry-over and lifecycle gaps, preserving existing owners.
- [ ] M4: independent review, full-project GUT, integrated smoke and owner checklist.
- [x] Independently review material changes and resolve all R-findings (latest console R7 FIXED).
- [ ] Run final task validation according to the documented GUT/headless budget.
- [x] Record remaining owner gameplay/visual QA under qa_tasks/.

### Decisions
This file is the authoritative router. Existing fixture smokes are dependency evidence, not a complete no-debug day walkthrough. Preserve the authored arrival-to-physical-departure challenge, simple NPC 3+3 attacks/animation hooks/NavigationAgent and screen debug timers/conditions/tasks. Headless native-node/sound-state checks do not establish rendered/audio perception.

Owner feedback dated 2026-10-02 extends R23 with [thirteen QA tasks](roadmap_23_vertical_slice_validation/owner_qa.md), including corpse/meat, inventory grid, future AI integration preparation and editable highlight materials/global overlay contract. The enlarged main scene and hidden DebugMarkers are authored owner changes; markers provide visual orientation only. Console/help extension is owned separately by [Developer Console Testing](developer_console_testing.md).

### Current

R23 owner-requested QA implementations and R24 M0–M6 complete; LOW console expansion/help/scroll complete. Owner full-day walkthrough, comfort of controls, routes, UI, visuals and audio remain unaccepted. Next: export latest main/test build and hand main scene to owner, as explicitly requested for full-slice testing. No rendered run or full no-debug walkthrough claimed. Dev only; preserve authored user edits/addons.

### Validation
CharacterBody: relevant GUT 46/46,571 assertions; final physics 6/6,33. Real controls/belt rays, fall/recontact/rebound, flying rigid response, support impulse, crouch, cart+15cm step, old authored-player save restore. MCP running native primitive player/input checked. Separate R2 lost cart step assistance FIXED/rereviewed. Structure/diff PASS; formatter SKIP. Both Windows exports79b6aefc actual scene + 120-frame startup PASS; full-day/visual acceptance pending.
2026-10-03 repair batch: focused control/Trader physical regression, Commerce, Jump and melee checks — 23/23 GUT, 143 assertions, no leaks (qa-controls-final-gut.log under .export). Main and exported Windows startup checked headlessly (120 frames); no game errors after scale-safe stair migration, external certificate-store warning recorded separately. Structure validator now accepts native SystemGroup auto_group initialization; formatter unavailable (SKIP). Separate read-only review found no material findings. These checks do not establish full-day or visual acceptance.
2026-10-02 QA task recording: project structure validator and changed-document diff check PASS; no gameplay implementation or runtime validation in this documentation update.

R22.5 dependency gate complete: 151/151 GUT (921 assertions), strict hazards/integrated main feedback smokes, static/structure/diff and independent review. R23 M1 authored manifest PASS; strict challenge_light-20261002-145614714.log PASS; diff PASS. R23-specific full-project GUT/no-debug day walkthrough has not run. M2 native bake PASS (156 polygons, no radius precision warning); draft logs r23_input_day_draft.log contain a failing handoff and are not final smoke evidence. Earlier draft eight-input-scans PASS had two native audio objects pending at accelerated shutdown; do not report it as strict leak-free PASS.

### Owner QA / blockers
Ручные проверки и результаты игроков: [сценарий QA](../qa_tasks/full_day.md).

Игровая приёмка ожидается; перенос не означает успешного прохождения. Реализация и автоматические доказательства остаются в этой задаче.

---

Зависимости: R01, R02, R03, R04, R05, R06, R06.1, R07, R08, R09, R10, R11, R11.1, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22, R22.5
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 00](../docs/roadmap/00_prototype_overview.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md), [ТЗ 18](../docs/roadmap/18_implementation_order.md), [canonical map](../docs/roadmap/README.md).

## Цель

Пройти законченный день до следующего утра без debug-команд и ручной перезагрузки сцены.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [docs/roadmap/17_vertical_slice_scenario.md](../docs/roadmap/17_vertical_slice_scenario.md)

Затем прочитать контракты, созданные задачами-зависимостями. Перед end-to-end validation подтвердить завершение [R22.5 GECS Architecture Polish](../task_history.md). Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Зафиксировать воспроизводимый набор 6–10 Package, оба опасных эффекта и четыре customer events: normal, light, gaze, floor.
- [ ] Пройти Morning: scan, Terminal, ручная маркировка/полки, повреждение/вскрытие.
- [ ] Проверить минимум один reusable extended-interaction path R11.1: prolonged action и физическое placement/fix-unfix без softlock.
- [ ] Пройти Day: обычная выдача, три разные challenge-семьи, ошибочная/повреждённая выдача, combat path и физические препятствия.
- [ ] Проверить минимум один альтернативный Package outcome из ТЗ 07: voluntary refusal + будущий физический unload/keep path (не Terminal-кнопка), Lost 120%, Player refusal 150% или false `TAKEN` + Complaint 200%. Убедиться, что actual outcome и Terminal declaration не схлопываются в одно поле.
- [ ] Пройти Evening: Trader, Food/MedItem, Quest и заказ; затем Sleep, autosave/load и PendingDelivery утром второго дня.
- [ ] Оставить минимум одну активную Package на второй день и подтвердить: номер сохраняется, Terminal показывает её, новая регистрация использует только действительно свободные номера, late-customer state не теряется.
- [ ] Проверить успешные и неуспешные исходы, потерянную посылку, добровольный/принудительный отказ, Complaint, смерть/поражение клиента и отсутствие softlock; исправлять разрывы существующих механик.
- [ ] Зафиксировать результаты, ограничения и manual playtest checklist в docs.

## Критерии готовности

- Сценарий Morning первого дня → Morning второго дня проходим без debug-команд.
- Есть минимум три разных опасных клиента плюс обычный; Light On/Off не считаются двумя разными семьями.
- Все обязательные пункты scope 00 покрыты; не остаётся блокирующих ошибок и расхождений сохранения.

## Проверки

Полный проектный GUT, headless smoke и ручной end-to-end walkthrough с записью результата; проверить критерии каждого источника 00/17. Общие команды и правила завершения — в [README](README.md).

## Границы

Помимо явно заказанного расширения QA-01–QA-13 — без новых крупных механик, процедурного расширения контента и кампании. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.

### QA-19 review

| ID | Severity | Finding | State | Evidence / decision |
| --- | --- | --- | --- | --- |
| R3 | P2 | Lamp flicker outlived customer cancellation/phase/death | FIXED | Challenge cleanup sends token-specific STOP; circuit-off clears immediately. Phase/removal/stale-token tests PASS; separate read-only re-review confirmed fix. |

### QA-06 review

| ID | Severity | Finding | State | Evidence / decision |
| --- | --- | --- | --- | --- |
| R4 | P2 | Floor instructions described old timings | FIXED | Rule12s preparation/48s danger/8s exposure matches60s total. Separate re-review confirmed fix. |

### Latest automated evidence / owner handoff

Major M2 full suite426/426,3375; no broad repeat for subsequent small edits. Focused inspection/customer prototype/console cases and actual-main native inspection/trader placement/developer-console smoke PASS; separate substantial reviews resolved findings. Latest console:22 existing regressions PASS,6 new parser tests52 assertions, R7 changed regression1/1,14, actual-main developer_console smoke PASS. Final Windows export follows logical commit. M2/M3 full ordinary-input day and alternative-outcome routes remain player QA; dependency/headless evidence is not a claim that these walkthroughs passed.
