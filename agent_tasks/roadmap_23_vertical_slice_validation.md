# R23 — Полный вертикальный срез

Status: **IN_PROGRESS**

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
- [ ] Owner QA batch: implement and verify [QA-01–QA-13](roadmap_23_vertical_slice_validation/owner_qa.md) on the enlarged main scene.
- [ ] M2: ordinary-input Morning → Day → Evening → Night → Morning walkthrough.
- [ ] M3: alternative outcomes/combat/carry-over and lifecycle gaps, preserving existing owners.
- [ ] M4: independent review, full-project GUT, integrated smoke and owner checklist.
- [ ] Independently review material changes and resolve all R-findings.
- [ ] Run final task validation according to the documented GUT/headless budget.
- [ ] Record remaining owner gameplay/visual QA.

### Decisions
This file is the authoritative router. Existing fixture smokes are dependency evidence, not a complete no-debug day walkthrough. Preserve the authored arrival-to-physical-departure challenge, simple NPC 3+3 attacks/animation hooks/NavigationAgent and screen debug timers/conditions/tasks. Headless native-node/sound-state checks do not establish rendered/audio perception.

Owner feedback dated 2026-10-02 extends R23 with [thirteen QA tasks](roadmap_23_vertical_slice_validation/owner_qa.md), including corpse/meat, inventory grid, future AI integration preparation and editable highlight materials/global overlay contract. The enlarged main scene and hidden DebugMarkers are authored owner changes; markers provide visual orientation only. Console/help extension is owned separately by [Developer Console Testing](developer_console_testing.md).

### Current
Owner feedback received and recorded as QA-01–QA-13. This update records tasks only. Next implementation step after resume: inspect current enlarged geometry, player control and Trader interaction before revalidating routes. Earlier bake/path results apply to the previous geometry and require revalidation.

Paused at the owner’s explicit request: full manual slice will be tested in main_level.tscn by the owner. M1 committed c33d40a9. M2 draft ordinary-input driver remains uncommitted in tests/smoke/vertical_slice_smoke.gd/.tscn; it substitutes only headless mouse capture, uses native input/physics/UI and an isolated save slot. It confirms eight scanner registrations, Terminal UI, ordinary NPC physical arrival and dialogue. No full-day PASS. Native warehouse bake radius was 0.35m rounded to 0.45m versus NPC 0.3m; uncommitted utility/resource correction to 0.3m reconnects the room/yard path. Bake utility now disables startup autosave. Latest draft stops at handoff: carried books still held, F prompt present, NPC becomes aggressive before delivery resolves. Cause is not yet established; investigate physical contact/attribution/timing after owner feedback. Preserve simple NPC 3+3 attacks and animation hooks.

### Validation
2026-10-02 QA task recording: project structure validator and changed-document diff check PASS; no gameplay implementation or runtime validation in this documentation update.

R22.5 dependency gate complete: 151/151 GUT (921 assertions), strict hazards/integrated main feedback smokes, static/structure/diff and independent review. R23 M1 authored manifest PASS; strict challenge_light-20261002-145614714.log PASS; diff PASS. R23-specific full-project GUT/no-debug day walkthrough has not run. M2 native bake PASS (156 polygons, no radius precision warning); draft logs r23_input_day_draft.log contain a failing handoff and are not final smoke evidence. Earlier draft eight-input-scans PASS had two native audio objects pending at accelerated shutdown; do not report it as strict leak-free PASS.

### Owner QA / blockers
User explicitly paused agent work to test the main scene. Do not continue full-day input automation without resume. No implementation blocker. Owner rendered full-day/readability/gamepad/audio playtest remains; keep implementation and automated evidence separate from that acceptance.

Feedback is now captured in the linked QA batch; none of its thirteen items is marked implemented. Further full-slice playtesting is handed to the owner as requested.

---

Зависимости: R01, R02, R03, R04, R05, R06, R06.1, R07, R08, R09, R10, R11, R11.1, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22, R22.5
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 00](../docs/roadmap/00_prototype_overview.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md), [ТЗ 18](../docs/roadmap/18_implementation_order.md), [canonical map](../docs/roadmap/README.md).

## Цель

Пройти законченный день до следующего утра без debug-команд и ручной перезагрузки сцены.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [docs/roadmap/17_vertical_slice_scenario.md](../docs/roadmap/17_vertical_slice_scenario.md)

Затем прочитать контракты, созданные задачами-зависимостями. Перед end-to-end validation подтвердить завершение [R22.5 GECS Architecture Polish](roadmap_22_5_gecs_architecture_polish.md). Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

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
