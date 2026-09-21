# R14 — Общий lifecycle челленджей и Light On/Off

Status: planned
Зависимости: R03, R12, R13
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 08](../docs/roadmap/08_customer_challenge_framework.md), [ТЗ 13](../docs/roadmap/13_environment_interactables.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Добавить data-driven Challenge lifecycle и первого опасного клиента со световым условием.

## Начать здесь

- [content/scenes/main_level.gd](../content/scenes/main_level.gd)
- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Реализовать Inactive → Armed → Active → Success/Failure → Cleanup, определения trigger/rules/timeout/consequences.
- [ ] Связать конкретный Challenge с Customer и получателями; не дублировать Customer AI в каждом варианте.
- [ ] Создать Light On/Off как две конфигурации одной проверки световой группы.
- [ ] Запускать после реплики, показывать правило и достаточный countdown; success/fail меняют Satisfaction и отправляют запрос escalation.
- [ ] Очистить таймеры/эффекты при завершении, удалении клиента, смерти игрока и смене фазы.

## Критерии готовности

- Клиент даёт ограниченное время физически переключить нужную группу света.
- On и Off используют общий код; результат применяется один раз, cleanup возвращает управление.

## Проверки

GUT: все переходы, timeout, повторный trigger, удаление, сброс дня; сценарии успеха и отказа у выключателя. Общие команды и правила завершения — в [README](README.md).

## Границы

Боевой получатель escalation — 17; пока последствие доступно через Satisfaction и typed event. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
