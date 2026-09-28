# R19 — Малый инвентарь, Food и MedItem

Status: **PLANNED**

## Task state

### Goal
Дать игроку хранить и использовать небольшие расходники с однозначным владельцем.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R02, R04, R08, R11.1, R18
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

Зависимости: R02, R04, R08, R11.1, R18
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 06](../docs/roadmap/06_package_damage_and_hazards.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 11](../docs/roadmap/11_hunger_system.md), [ТЗ 12](../docs/roadmap/12_inventory_and_consumables.md), [ТЗ 16](../docs/roadmap/16_ui_and_feedback.md).

## Цель

Дать игроку хранить и использовать небольшие расходники с однозначным владельцем.

## Начать здесь

- [content/components/interaction/c_interactable.gd](../content/components/interaction/c_interactable.gd)
- [content/definitions/definition.gd](../content/definitions/definition.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Добавить Item definitions/runtime quantity и authoritative OwnedBy → InventoryOwner. Не использовать virtual Inventory как authority для physical slots из R11.1.
- [ ] Реализовать pickup, stacking совместимых consumables, use и удаление пустого стека.
- [ ] Food вызывает эффект 18, MedItem — лечение 04; списание quantity и применение результата согласованы.
- [ ] Добавить Consumable "Bubble Wrap": одно использование на валидной Package применяет protection modifier из R08 одним действием и списывает один consumable; сам damage/protection расчет не дублировать в Inventory.
- [ ] Добавить простой UI без authority над item state; исключить Package/Furniture из обычного Inventory.
- [ ] Задать контракт transfer для Trader/container/loot, не реализуя все источники сразу.

## Критерии готовности

- Игрок подбирает Food, MedItem и Bubble Wrap, видит количество и использует их; Bubble Wrap одним действием защищает выбранную Package по contract R08.
- Два owner невозможны, использование не дублируется, quantity не отрицательна; большая Package остаётся физически в мире.

## Проверки

GUT: ownership/transfer, stack, повторное use, лечение/еда, Bubble Wrap apply/consume, cleanup; walkthrough UI. Общие команды и правила завершения — в [README](README.md).

## Границы

Без сетки размещения и полного контейнерного/loot framework. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
