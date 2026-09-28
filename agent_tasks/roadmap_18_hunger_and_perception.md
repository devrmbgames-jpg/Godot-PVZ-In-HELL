# R18 — Голод, модификаторы и восприятие

Status: **PLANNED**

## Task state

### Goal
Добавить Hunger как игровое состояние с обратимыми эффектами и искажением восприятия.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R03, R04, R12, R17
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

Зависимости: R03, R04, R12, R17
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 09](../docs/roadmap/09_dialogue_system.md), [ТЗ 11](../docs/roadmap/11_hunger_system.md).

## Цель

Добавить Hunger как игровое состояние с обратимыми эффектами и искажением восприятия.

## Начать здесь

- [CharacterMotionSolver](../content/services/motion/character_motion_solver.gd)
- [content/components/motion/c_carry_load.gd](../content/components/motion/c_carry_load.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Добавить числовой Hunger, Normal/Hungry/Starving и рост только в активном игровом времени; определить паузу и Night.
- [ ] Создать публичный gameplay-effect Food для снижения Hunger; получение/расход стека подключит задача 19.
- [ ] Сочетать hunger speed/damage modifiers с carry через effective значения, не перемножая базовые параметры на входе/выходе.
- [ ] В Starving визуально представить NPC как еду и заменить воспринимаемые реплики вариантами «Съешь меня».
- [ ] Сохранять реальные Entity, условия, dialogue transitions и quest flags неизменными.

## Критерии готовности

- Голод растёт, Food снижает его; speed и attack damage меняются и возвращаются без накопления ошибки.
- Carry и Hunger действуют одновременно; визуальная/текстовая замена не меняет получателя заказа или ветки диалога.

## Проверки

GUT: tiers/границы/время/обратимость/совместные модификаторы; integration dialogue+perception. Общие команды и правила завершения — в [README](README.md).

## Границы

Без поедания клиентов и hunger abilities; backend эффекта еды здесь, Inventory use — 19. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
