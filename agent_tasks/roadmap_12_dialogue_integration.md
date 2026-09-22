# R12 — Диалоги, условия и загадка

Status: planned
Зависимости: R02, R11, R11.1
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 07](../docs/roadmap/07_customer_flow_and_delivery.md), [ТЗ 08](../docs/roadmap/08_customer_challenge_framework.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 09](../docs/roadmap/09_dialogue_system.md).

## Цель

Подключить диалоговый слой к gameplay без переноса authority в текст/UI.

## Начать здесь

- [project.godot](../project.godot)
- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Оценить уже установленный DialogueManager через локальный API; использовать его без изменения addons и без второго параллельного движка.
- [ ] Добавить типизированный адаптер conditions/actions: фаза, Satisfaction, RequestedPackage, Package actual outcome, Terminal declaration, Complaint/dispute state, Opened/Damaged flags, результаты Challenge и будущий Hunger tier.
- [ ] Собрать прямой диалог с номером и загадку с выбором/повтором/альтернативной веткой.
- [ ] Действия диалога вызывают существующие gameplay-контракты; поддержать voluntary Customer refusal, delayed Complaint и обнаружение false `TAKEN` с переходом в Aggressive. Challenge/Aggressive подключаются через получателей, а не через циклическую зависимость реализации.
- [ ] Разделить действительную реплику/переход и воспринимаемый текст для последующей Hunger distortion.

## Критерии готовности

- Номер доступен через разговор, но поиск коробки остаётся задачей игрока.
- Неверный ответ влияет на Satisfaction и ветку; повтор/закрытие разговора не дублирует выдачу или событие.

## Проверки

GUT: conditions/actions и идемпотентность; integration прямого диалога и загадки; smoke закрытия при уходе/смерти NPC. Общие команды и правила завершения — в [README](README.md).

## Границы

Полная Hunger distortion — 18; не изменять плагин DialogueManager. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
