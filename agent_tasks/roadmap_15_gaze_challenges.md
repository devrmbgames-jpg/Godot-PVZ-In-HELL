# R15 — Don't Look / Keep Looking

Status: **OWNER_QA**

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
- [x] Reconfirm dependency completion and current production owners/contracts.
- [x] Implement the existing work checklist in small coherent milestones.
- [x] Independently review material changes and resolve all R-findings.
- [x] Run final task validation according to the documented GUT/headless budget.
- [x] Record remaining owner gameplay/visual QA.

### Decisions
This file owns the feature state. Base: R14 b1238958, local master.
- Player experience: retrieve/service a physical parcel while managing attention. Pillars: readable danger, physical agency and a shared customer loop.
- Actual camera/head transform supplies gaze, independent of requested look input. One evaluator checks angle, range and physics LOS; the two modes differ by required attention data.
- Generic lifecycle owns continuous violation time/reset and final results. A new completion mode waits for departure on success but fails immediately at the violation threshold. Existing light visit variant keeps its original departure-only consequence.
- Authored hypothesis: 20-degree attention cone, 12-metre range, 3-second preparation and 3-second continuous violation budget. Warning starts halfway; owner playtest must verify parcel searching remains possible.
- Warning is HUD/world presentation only; no camera/physics/Customer identity mutation. Motion reduction is exposed in HUD configuration. Debug UI reports geometry, LOS, continuous timer and threshold.
- A separate default bottle-customer profile uses Don't Look; Keep Looking is another configuration using the same evaluator.

### Current
Shared geometry/LOS producer, inverse configurations, continuous reset policy, immediate failure mode, authored bottle-customer and warning/debug HUD implemented. Independent read-only reviewer reports no material findings. Next queue task: R16 floor hazard challenge.

### Validation
- GUT gaze/light/dialogue/customer flow: 65/65 PASS, 561 assertions, clean shutdown (r15_final_gut.log). Covers angle/range boundaries, own/unrelated camera pose, real wall LOS, inverse modes, preparation, continuous/reset/accumulating time, short final violation, consequence once and relationship cleanup.
- Strict challenge_gaze smoke PASS: authored customer and actual dialogue acknowledgement, camera-driven warning/debug HUD, recovery, physical counter parcel overlap/delivery, departure result before payment and cleanup. Strict challenge_light regression PASS.
- Project structure and diff whitespace PASS. Direct main scene headless 120-frame startup/shutdown has no game script/resource/RID errors; external certificate-store error remains.
- Default schedule now has four daily visits and one ten-day-delayed visit; its idempotence/profile test migrated and passed. Only registered packages become actionable, preserving prior smoke flow.
- Formatter unavailable; no rendered/visual check claimed.

### Owner QA / blockers
Ручные проверки и результаты игроков: [сценарий QA](../qa_tasks/environment_and_challenges.md).

Игровая приёмка ожидается; перенос не означает успешного прохождения. Реализация и автоматические доказательства остаются в этой задаче.

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

- [x] Определить gaze tracking с углом, дистанцией и LOS, а не только направлением камеры.
- [x] Don't Look измеряет непрерывное внимание; Keep Looking — непрерывную потерю внимания, на общем механизме.
- [x] Вынести пороги, время и правила сброса в definition.
- [x] Подключить предупреждающее distortion/поведение, success/failure и общий cleanup.
- [x] Создать отдельного Customer-профиля и последовательность обслуживания во время активного правила.

## Критерии готовности

- Препятствие корректно влияет на видимость; два режима отличаются конфигурацией.
- Игрок может искать Package под давлением правила; failure вызывает gameplay outcome, а distortion не меняет Customer identity.

## Проверки

GUT: угол/LOS/таймеры, границы и reset; integration смены цели и завершения; ручная проверка понятности предупреждения. Общие команды и правила завершения — в [README](README.md).

## Границы

Для финального сценария достаточно одного режима; оба конфигурируются общей базой. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
