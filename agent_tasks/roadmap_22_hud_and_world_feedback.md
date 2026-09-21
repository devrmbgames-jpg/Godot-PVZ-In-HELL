# R22 — HUD и читаемость систем

Status: planned
Зависимости: R06, R07, R08, R09, R14, R15, R16, R17, R18, R19, R20
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 05](../docs/roadmap/05_scanner_terminal_marker.md), [ТЗ 06](../docs/roadmap/06_package_damage_and_hazards.md), [ТЗ 08](../docs/roadmap/08_customer_challenge_framework.md), [ТЗ 11](../docs/roadmap/11_hunger_system.md), [ТЗ 12](../docs/roadmap/12_inventory_and_consumables.md), [ТЗ 16](../docs/roadmap/16_ui_and_feedback.md).

## Цель

Завершить пользовательскую обратную связь поверх уже работающих систем, не перенося gameplay в меню.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [docs/physical_grab.md](../docs/physical_grab.md)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Расширить ранний HUD из 02 показателями Health/Hunger и Money там, где это полезно.
- [ ] Проверить доступность и актуальность prompt во всех контекстах, включая dialogue/tool/throw/combat.
- [ ] Показать Fragile/Heavy/Liquid и Damaged/Opened на самих коробках, а не только в HUD.
- [ ] Проверить scan beep/подтверждение/Terminal, требования Challenge, gaze warning и достаточный countdown.
- [ ] Различить feedback повреждения игрока, коробки, ToxicLeak и Explosion; убрать debug-зависимости.

## Критерии готовности

- Без debug UI понятны доступные действия, параметры игрока, свойства Package и последствия опасностей.
- UI/звук/визуальные эффекты подписаны на состояние/результаты; их отключение не меняет gameplay.

## Проверки

GUT: привязки и cleanup UI там, где логика существенна; ручная проверка читаемости полного сценария. Общие команды и правила завершения — в [README](README.md).

## Границы

Не переносить весь feedback на этот этап: минимальный результат должен быть читаем уже в каждой owning-задаче. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
