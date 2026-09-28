# R15 — Don't Look / Keep Looking

Status: **PLANNED**

## Task state

### Goal
Добавить семейство челленджей, где игрок обслуживает клиента под ограничением взгляда.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R14
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

Зависимости: R14
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 08](../docs/roadmap/08_customer_challenge_framework.md), [ТЗ 16](../docs/roadmap/16_ui_and_feedback.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Добавить семейство челленджей, где игрок обслуживает клиента под ограничением взгляда.

## Начать здесь

- [CharacterLookSolver](../content/services/motion/character_look_solver.gd)
- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [ ] Определить gaze tracking с углом, дистанцией и LOS, а не только направлением камеры.
- [ ] Don't Look измеряет непрерывное внимание; Keep Looking — непрерывную потерю внимания, на общем механизме.
- [ ] Вынести пороги, время и правила сброса в definition.
- [ ] Подключить предупреждающее distortion/поведение, success/failure и общий cleanup.
- [ ] Создать отдельного Customer-профиля и последовательность обслуживания во время активного правила.

## Критерии готовности

- Препятствие корректно влияет на видимость; два режима отличаются конфигурацией.
- Игрок может искать Package под давлением правила; failure вызывает gameplay outcome, а distortion не меняет Customer identity.

## Проверки

GUT: угол/LOS/таймеры, границы и reset; integration смены цели и завершения; ручная проверка понятности предупреждения. Общие команды и правила завершения — в [README](README.md).

## Границы

Для финального сценария достаточно одного режима; оба конфигурируются общей базой. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
