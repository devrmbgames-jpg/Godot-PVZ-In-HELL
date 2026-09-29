# R23 — Полный вертикальный срез

Status: **PLANNED**

## Task state

### Goal
Пройти законченный день до следующего утра без debug-команд и ручной перезагрузки сцены.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R01, R02, R03, R04, R05, R06, R06.1, R07, R08, R09, R10, R11, R11.1, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22, R22.5
- Reuse existing authoritative contracts from completed dependencies; do not duplicate them.
- The existing `## Работы`, `## Критерии готовности`, `## Проверки`, and `## Границы` sections remain the detailed implementation specification.
- Follow Godot 4.7, GECS ownership, physics authority, and validation rules from `AGENTS.md`.

### Milestones
- [ ] Reconfirm dependency completion and current production owners/contracts.
- [ ] Implement the existing work checklist in small coherent milestones.
- [ ] Independently review material changes and resolve all R-findings.
- [ ] Run final task validation according to the documented GUT/headless budget.
- [ ] Record remaining owner gameplay/visual QA.

### Decisions
Do not create a parallel planning document. This file remains the authoritative state/router for the feature; source design docs are references, not task state.

### Current
Not started under the lean workflow. Next: verify dependencies in `task_history.md` and current code, then choose the first bounded implementation milestone from the existing work list.

### Validation
Not run for this task under the lean workflow.

### Owner QA / blockers
No new blocker is recorded. Any unmet dependency discovered during startup moves the task to `BLOCKED` or `DEFERRED` with the exact dependency named.

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

- [ ] Зафиксировать воспроизводимый набор 6–10 Package, оба опасных эффекта и четыре customer events: normal, light, gaze, floor.
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

Без новых крупных механик, процедурного расширения контента и кампании. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
