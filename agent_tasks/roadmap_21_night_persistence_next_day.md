# R21 — Сон, autosave и следующее утро

Status: **PLANNED**

## Task state

### Goal
Замкнуть цикл и сохранить долгосрочные результаты в одном autosave slot.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R03, R05, R09, R11, R11.1, R14, R18, R19, R20
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

Зависимости: R03, R05, R09, R11, R11.1, R14, R18, R19, R20
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 03](../docs/roadmap/03_day_phase_cycle.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 14](../docs/roadmap/14_evening_meta_scaffold.md), [ТЗ 15](../docs/roadmap/15_night_save_next_day.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Замкнуть цикл и сохранить долгосрочные результаты в одном autosave slot.

## Начать здесь

- [content/scenes/main_level.gd](../content/scenes/main_level.gd)
- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] SleepPoint запускает одну транзакцию Night: результаты, persistent snapshot, PendingDelivery, DayIndex и новый Morning.
- [ ] Сохранить минимум DayIndex, Money/Penalties, Health, Hunger, upgrades/purchases, quest flags, PendingDeliveries; дополнительно сохранить Inventory и связи identity, необходимые уже работающим задачам.
- [ ] Сохранять активные/невыданные Package через любое число дней: stable identity, reusable registration number, состояние Opened/Damaged, ownership/physical persistence и RequestedPackage identity. Ночь сама по себе не освобождает номер.
- [ ] Сохранять actual delivery outcome отдельно от Terminal declaration, unresolved Complaints/disputes, примененные settlement operation IDs и 7-day justified-retaliation windows.
- [ ] Сохранять persistent physical-slot/placement/fixed-object state из R11.1 там, где объект должен переживать ночь; временный interaction progress/control capture не сохранять.
- [ ] Сбрасывать schedule, временные challenges/dialogue/hazards/reservations; сохранять явно persistent последствия.
- [ ] Определить политику физического расположения и маркерных штрихов между днями; исключить потерю quest-target и дубликаты ID. Customer arrival может быть запланирован через 10+ дней либо никогда, поэтому отсутствие события сегодня не является cleanup condition.
- [ ] Поддержать morning return отказной Package: lifecycle/номер закрываются только после successful return commit; существующая Complaint/штраф не отменяются автоматически.
- [ ] Восстанавливать ссылки по стабильным ID, не сериализовать Node/Relationship runtime напрямую; безопасно обрабатывать отсутствующий/некорректный save.
- [ ] Доставлять каждый оплаченный order ровно один раз даже после повторного load или прерывания перехода.

## Критерии готовности

- Morning второго дня сохраняет необходимые характеристики и quest flags, приносит заказанный предмет.
- Зарегистрированная, но невыданная Package предыдущего дня остается физически/логически активной с тем же номером; unresolved dispute переживает save/load без повторного штрафа. Если package-pickup Customer был due, но NPC не появился из-за отсутствия registration record, а Package к следующему Morning всё ещё не зарегистрирована, визит автоматически закрывается как LOST без спавна NPC, штрафуется один раз и Package удаляется из физического склада.
- Перезапуск игры восстанавливает согласованное состояние; повтор Sleep/load не дублирует доставку или DayIndex.
- Нет оставшегося slowdown, rotation lock или временной опасности после reset.

## Проверки

GUT: round-trip, missing/corrupt save, reset/persist, повторное применение delivery; integration Night → restart → Morning. Общие команды и правила завершения — в [README](README.md).

## Границы

Один autosave slot; без облака, multiplayer и полного редактора сохранений. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
