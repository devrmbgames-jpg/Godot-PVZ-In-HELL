# R18 — Голод, модификаторы и восприятие

Status: **OWNER_QA**

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
- [x] Reconfirm dependency completion and current production owners/contracts.
- [x] Implement the existing work checklist in small coherent milestones.
- [x] Independently review material changes and resolve all R-findings.
- [x] Run final task validation according to the documented GUT/headless budget.
- [x] Record remaining owner gameplay/visual QA.

### Decisions
Do not create a parallel planning document. This file remains the authoritative state/router for the feature; source design docs are references, not task state.

- Active time is Morning/Day/Evening while the actor is alive and SceneTree is unpaused; Night is excluded. Modal dialogue follows existing customer timers and does not pause world time.
- Authored hunger policy supplies numeric maximum, two thresholds, growth and speed/intentional-attack multipliers. Effective reads combine carry and hunger; no baseline mutation or repeated enter/exit multiplication.
- Starving food visual and perceived NPC text are presentation only. Player responses retain their authored choices and routing tags. Food is a public typed effect backend; R19 supplies acquisition/stack/use.

### Current
Implementation complete: authored policy/state, active-time System, typed Food effect, reversible carry+hunger speed and melee/projectile damage, food visual/perceived NPC lines and debug timers/conditions/tasks. Projectile damage is snapshotted at launch; physical impact/hazard formulas retain R08 authority. Next: R19 pickup/stack/use invokes Food and consumes quantity only after success.

### Validation
- Final focused GUT: 69/69 PASS, 725 assertions across Hunger, perception, dialogue, player melee, NPC attacks, main grab and customer flow (`tests/artifacts/r18_final_gut.log`). Includes real damage, projectile snapshot and unchanged dialogue routing/body identity.
- Strict main-scene Hunger smoke PASS (`hunger-20261002-064316291.log`): growth, Food, physical carry, real customer perception/order/physics identity, damage and death settlement. Combat regression PASS (`combat-20261002-064705334.log`).
- Structure validator and `git diff --check` PASS. Main 120-frame headless shutdown has no project errors/leaks; external Windows certificate-store error remains. Editor import resolved classes but plugin errors prevent claiming a clean editor check. Formatter unavailable.
- Resulting diff reviewed independently in the main session; no material open findings.

### Owner QA / blockers
Ручные проверки и результаты игроков: [сценарий QA](../qa_tasks/combat_hunger_inventory.md).

Игровая приёмка ожидается; перенос не означает успешного прохождения. Реализация и автоматические доказательства остаются в этой задаче.

---

Зависимости: R03, R04, R12, R17
Ветка/base: master / `4615d3b3`.
Источники: [ТЗ 09](../docs/roadmap/09_dialogue_system.md), [ТЗ 11](../docs/roadmap/11_hunger_system.md).

## Цель

Добавить Hunger как игровое состояние с обратимыми эффектами и искажением восприятия.

## Начать здесь

- [CharacterMotionSolver](../content/services/motion/character_motion_solver.gd)
- [content/components/motion/c_carry_load.gd](../content/components/motion/c_carry_load.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Добавить числовой Hunger, Normal/Hungry/Starving и рост только в активном игровом времени; определить паузу и Night.
- [x] Создать публичный gameplay-effect Food для снижения Hunger; получение/расход стека подключит задача 19.
- [x] Сочетать hunger speed/damage modifiers с carry через effective значения, не перемножая базовые параметры на входе/выходе.
- [x] В Starving визуально представить NPC как еду и заменить воспринимаемые реплики вариантами «Съешь меня».
- [x] Сохранять реальные Entity, условия, dialogue transitions и quest flags неизменными.

## Критерии готовности

- Голод растёт, Food снижает его; speed и attack damage меняются и возвращаются без накопления ошибки.
- Carry и Hunger действуют одновременно; визуальная/текстовая замена не меняет получателя заказа или ветки диалога.

## Проверки

GUT: tiers/границы/время/обратимость/совместные модификаторы; integration dialogue+perception. Общие команды и правила завершения — в [README](README.md).

## Границы

Без поедания клиентов и hunger abilities; backend эффекта еды здесь, Inventory use — 19. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
