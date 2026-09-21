# R19 — Малый инвентарь, Food и MedItem

Status: planned
Зависимости: R02, R04, R18
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 11](../docs/roadmap/11_hunger_system.md), [ТЗ 12](../docs/roadmap/12_inventory_and_consumables.md), [ТЗ 16](../docs/roadmap/16_ui_and_feedback.md).

## Цель

Дать игроку хранить и использовать небольшие расходники с однозначным владельцем.

## Начать здесь

- [content/components/interaction/c_interactable.gd](../content/components/interaction/c_interactable.gd)
- [content/definitions/definition.gd](../content/definitions/definition.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Добавить Item definitions/runtime quantity и authoritative OwnedBy → InventoryOwner.
- [ ] Реализовать pickup, stacking совместимых consumables, use и удаление пустого стека.
- [ ] Food вызывает эффект 18, MedItem — лечение 04; списание quantity и применение результата согласованы.
- [ ] Добавить простой UI без authority над item state; исключить Package/Furniture из обычного Inventory.
- [ ] Задать контракт transfer для Trader/container/loot, не реализуя все источники сразу.

## Критерии готовности

- Игрок подбирает Food и MedItem, видит количество и использует их.
- Два owner невозможны, использование не дублируется, quantity не отрицательна; большая Package остаётся физически в мире.

## Проверки

GUT: ownership/transfer, stack, повторное use, лечение/еда, cleanup; walkthrough UI. Общие команды и правила завершения — в [README](README.md).

## Границы

Без сетки размещения и полного контейнерного/loot framework. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
