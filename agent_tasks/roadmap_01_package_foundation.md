# R01 — Package и базовые gameplay-контракты

Status: planned
Зависимости: нет; готова к старту
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 00](../docs/roadmap/00_prototype_overview.md), [ТЗ 01](../docs/roadmap/01_gecs_gameplay_model.md), [ТЗ 02](../docs/roadmap/02_core_interaction_and_physics.md).

## Цель

Расширить существующий GECS-прототип минимальной моделью посылки, сохранив работающие Player, прыжок и физический хват.

## Начать здесь

- [content/entities/props/box.tscn](../content/entities/props/box.tscn)
- [content/entities/props/e_grabbable.gd](../content/entities/props/e_grabbable.gd)
- [content/components/gameplay/c_health.gd](../content/components/gameplay/c_health.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Сверить текущие компоненты с roadmap; не создавать повторно World, Controller, Interactor, HeldBy и CarryLoad.
- [ ] Добавить постоянный Package ID, номер отправления, описание, комментарий, адресата и составные теги Normal/Fragile/Heavy/Liquid.
- [ ] Отделить definition-данные от runtime регистрации, сканирования, открытия и повреждения; задать исходные состояния.
- [ ] Определить будущую связь AssignedTo с Customer; до появления Customer хранить стабильный идентификатор адресата, а не фиктивный Node.
- [ ] Собрать Package на базе физической коробки и зарегистрировать в настоящем World.

## Критерии готовности

- Две посылки имеют разные стабильные ID и независимое runtime-состояние; сочетание Heavy+Fragile допустимо.
- Новая Package — Unregistered, NotScanned, Closed, Undamaged; существующее взаимодействие и прыжок не сломаны.

## Проверки

GUT: уникальность ID, начальные состояния, независимость экземпляров, композиция тегов; загрузка main_level. Общие команды и правила завершения — в [README](README.md).

## Границы

Без Customer AI, генерации поставок и поведения повреждений. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
