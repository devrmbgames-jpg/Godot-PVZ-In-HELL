# R11 — Клиенты, расписание и физическая выдача

Status: planned
Зависимости: R03, R06, R08, R10
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 01](../docs/roadmap/01_gecs_gameplay_model.md), [ТЗ 07](../docs/roadmap/07_customer_flow_and_delivery.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Провести обычного Customer от прихода до получения физической посылки и ухода.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [content/components/gameplay/c_controller.gd](../content/components/gameplay/c_controller.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Добавить Customer Entity с data-driven lifecycle и расписание 3–5 обязательных событий Day.
- [ ] Создать authoritative AssignedTo и контракт RequestedPackage; сверять выдачу по identity, а не только отображаемому номеру.
- [ ] Реализовать Approaching/Waiting/WaitingForPackage/Receiving/Leaving/Finished и входы в будущие Dialogue/Aggressive/OptionalFitting.
- [ ] DeliveryCounter проверяет реально принесённую Package и явное подтверждение; unregistered/wrong/damaged/opened дают разные результаты.
- [ ] Выводить Satisfaction и денежный результат через контракт 10; определять успешное/неуспешное завершение события без softlock.

## Критерии готовности

- Обычный клиент сообщает номер временной минимальной репликой, получает правильный заказ и уходит.
- Неверная посылка не выдаётся автоматически; повреждение/вскрытие учитываются при выдаче.
- Завершение всех обязательных событий открывает Evening; смерть/уход/потерянная посылка имеют явный исход.

## Проверки

GUT: все варианты выдачи, однократная оплата, ownership, расписание; gameplay walkthrough с физической коробкой. Общие команды и правила завершения — в [README](README.md).

## Границы

Полный диалог — 12; полноценная примерочная не обязательна. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
