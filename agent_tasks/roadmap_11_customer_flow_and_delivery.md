# R11 — Клиенты, расписание и физическая выдача

Status: planned
Зависимости: R03, R06, R08, R10
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 01](../docs/roadmap/01_gecs_gameplay_model.md), [ТЗ 07](../docs/roadmap/07_customer_flow_and_delivery.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Провести Customer от прихода до физической выдачи/отказа/спора, не принуждая Player к честному исходу. Package и связанные Customer records могут жить много дней.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [content/components/gameplay/c_controller.gd](../content/components/gameplay/c_controller.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Добавить Customer Entity с data-driven lifecycle и расписание 3–5 обязательных событий Day. Arrival конкретной Package может быть сегодня, через 10+ дней или не произойти вообще; это не должно удалять Package или освобождать её номер.
- [ ] Создать authoritative AssignedTo и контракт RequestedPackage; сверять выдачу по identity, а не только отображаемому номеру.
- [ ] Реализовать Approaching/Waiting/WaitingForPackage/Receiving/Leaving/Finished и входы в будущие Dialogue/Aggressive/OptionalFitting.
- [ ] DeliveryCounter проверяет реально принесённую Package и явное подтверждение; unregistered/wrong/damaged/opened дают разные результаты, но opened/damaged не обязаны автоматически запрещать выдачу.
- [ ] Разделить authoritative actual outcome (`DELIVERED/CUSTOMER_REFUSED/PLAYER_DENIED/NOT_RESOLVED`) и Terminal declaration (`TAKEN/REFUSED/LOST/NONE`). Ложный `TAKEN` разрешён и сохраняется как расхождение, а не исправляется UI.
- [ ] Реализовать Terminal closeout: «Забрал / Отказался / Потеряна», с сохранением последней покинувшей lifecycle Package в Terminal history.
- [ ] Добавить Complaint/dispute record: корректная/ложная жалоба, delayed resolution, small immediate aggression chance при обнаруженном false `TAKEN`.
- [ ] Добровольный Customer refusal и Player denial должны быть разными reasons. Добровольный отказ позволяет morning return либо buyout 100%; Player denial всегда создаёт negative Reputation hook.
- [ ] Выводить Satisfaction и денежный результат через контракт 10; Lost = 120%, Player refusal = 150%, подтвержденный concealed/fraudulent refusal = 200%; определять исход без softlock.

## Критерии готовности

- Обычный клиент сообщает номер временной минимальной репликой, получает правильный заказ и уходит; Terminal declaration хранится отдельно от факта выдачи.
- Неверная посылка не выдаётся автоматически; повреждение/вскрытие учитываются при выдаче.
- Завершение всех обязательных событий открывает Evening; смерть/уход/потерянная/отказная посылка имеют явный исход.
- Package без пришедшего Customer остаётся активной между днями и продолжает занимать регистрационный номер.
- Complaint может разрешиться позже ухода Customer и не зависит от живого Node reference.

## Проверки

GUT: все варианты выдачи, однократная оплата, ownership, расписание; gameplay walkthrough с физической коробкой. Общие команды и правила завершения — в [README](README.md).

## Границы

Полный диалог — 12; полноценная примерочная не обязательна. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
