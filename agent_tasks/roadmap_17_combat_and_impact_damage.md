# R17 — Ближний бой и агрессивный Customer

Status: planned
Зависимости: R04, R11, R14
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 02](../docs/roadmap/02_core_interaction_and_physics.md), [ТЗ 07](../docs/roadmap/07_customer_flow_and_delivery.md), [ТЗ 10](../docs/roadmap/10_combat_damage_health.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Дать игроку и опасному клиенту общий физический боевой сценарий.

## Начать здесь

- [content/systems/interaction/s_grab.gd](../content/systems/interaction/s_grab.gd)
- [content/systems/motion/s_motion.gd](../content/systems/motion/s_motion.gd)
- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Добавить один melee/острый Weapon: окно удара, hit validation, cooldown и damage через 04.
- [ ] Aggressive Customer прекращает сервисный разговор, преследует и атакует Player; имеет поражение и завершение schedule event. Один из источников aggression — обнаружение ложной Terminal отметки `TAKEN` по ТЗ 07.
- [ ] Подключить физический impact damage по массе, относительной скорости и порогу; подавить повторные срабатывания одного столкновения.
- [ ] Соблюдать приоритет tool/grab/attack из 02, сохраняя input неизменным для других потребителей.
- [ ] Обеспечить cleanup target/challenge/held state при смерти и выходе из боя.
- [ ] Передавать typed combat/reputation reason: обычная атака, self-defense, fraud escalation, justified retaliation. После подтвержденной неправомерной Complaint именно этого Customer Player может атаковать 7 игровых дней без reputation penalty; окно хранится persistent и не зависит от живого Node.

## Критерии готовности

- Клиент ранит Player; игрок побеждает оружием или тяжёлым предметом.
- Слабое касание не наносит урон, собственный held object не бьёт держателя; одно ЛКМ не бросает и не атакует одновременно.
- Коробки блокируют проход и остаются частью физического боя.
- Combat не применяет Reputation напрямую, но сохраняет reason/context так, чтобы future Reputation могла корректно отличить разрешенную retaliation от обычной атаки.

## Проверки

GUT: hit/cooldown/дедупликация/смерть; physics integration impact; walkthrough escalation из Light Challenge. Общие команды и правила завершения — в [README](README.md).

## Границы

Без полного арсенала и сложной боевой AI. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
