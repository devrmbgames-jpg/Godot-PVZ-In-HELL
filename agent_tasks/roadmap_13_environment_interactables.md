# R13 — Двери, окна, ящики мебели и свет

Status: **PLANNED**

## Task state

### Goal
Сделать помещение интерактивным и подготовить физическое окружение для челленджей.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R02, R11.1
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

Зависимости: R02, R11.1
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 02](../docs/roadmap/02_core_interaction_and_physics.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 13](../docs/roadmap/13_environment_interactables.md).

## Цель

Сделать помещение интерактивным и подготовить физическое окружение для челленджей.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [content/systems/interaction/s_interaction_targeting.gd](../content/systems/interaction/s_interaction_targeting.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Добавить Door и Window с открыть/закрыть и читаемым состоянием, переиспользуя open/close/access contracts R11.1.
- [ ] Добавить Drawer с ограниченным ходом и interaction state поверх translate/prolonged-interaction contracts R11.1.
- [ ] Двери и выдвижные элементы должны учитывать препятствия без телепортации через коробку.
- [ ] LightSwitch управляет заданными группами света; gameplay-состояние доступно будущим Challenge conditions.
- [ ] Использовать единые targeting, highlight и prompts; оставить data-hook для locks/storage.

## Критерии готовности

- Все четыре типа работают через общий interaction framework.
- Коробка физически мешает закрытию двери; удаление/блокировка объекта не оставляет неверный prompt.

## Проверки

GUT: переключения/недоступность/световые группы; integration двери с коробкой и ограничений drawer; ручной walkthrough. Общие команды и правила завершения — в [README](README.md).

## Границы

Без полноценного key/inventory UI и контейнерного stack Inventory: generic access requirement и physical slots уже принадлежат R11.1, а virtual Inventory — R19. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
