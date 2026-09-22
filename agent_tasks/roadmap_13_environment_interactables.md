# R13 — Двери, окна, ящики мебели и свет

Status: planned
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

Без системы ключей/замков и контейнерного инвентаря. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
