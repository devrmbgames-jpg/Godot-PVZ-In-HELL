# R16 — Клиент с опасным полом

Status: **OWNER_QA**

## Task state

### Goal
Создать третий отличный от света и взгляда челлендж, решаемый предметами мира.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R09, R14
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
This file owns feature state. Base: R15 6247b4cc; R09 completion confirmed in task_history and direct damage/hazard services.
- Experience: read the floor warning, climb/reposition physical boxes or use the safe perimeter, then service the customer. Pillars: readable danger, physical agency, shared customer lifecycle.
- Use actual CharacterMotionSolver support contact (world contact position and collider RID) to distinguish floor from elevated box support; no XZ projection-only damage and no transform override.
- Autonomous floor prefab uses R09 spawn/attribution/damage/retirement. Subject-to-effect ownership is a challenge Relationship. Generic lifecycle owns preparation, continuous contact limit and duration result.
- Authored hypothesis: 3 seconds preparation, 12 seconds danger, half-second damage ticks and 2 seconds continuous floor contact before challenge failure. Owner playtest must verify route/climb feasibility.
- Add safe physical movable boxes outside/inside the marked zone and a separate tools-customer profile. Debug UI shows preparation/duration, actual support height, contact state and violation/damage timer.

### Current
Actual support snapshot, autonomous floor prefab, challenge effect Relationship, generic duration/contact outcome, tools customer and three movable support boxes implemented. Independent review R1 session/damage ordering fixed and re-reviewed. Next queue task: R17 combat/impact.

### Validation
- GUT floor/gaze/light/customer flow/main grab: 65/65 PASS, 522 assertions; clean shutdown (r16_final_gut.log). Floor surface/bounds, elevated/airborne support, damage ticks/reset, duration overrun, NoDamage, duplicate consequence and actor/subject/effect/day/phase cleanup covered.
- Strict challenge_floor smoke PASS: real Jolt floor support damages through O_Damage; movable box top remains safe; airborne support clears; default tools profile, authored boxes and actual debug contact/damage timer present; effect cleanup validated.
- Strict regressions npc_navigation, challenge_light and challenge_gaze PASS. Direct main headless startup/shutdown (120 frames) has no game script/resource/RID errors; external certificate-store error remains.
- Project structure and diff whitespace PASS. Formatter unavailable; rendered gameplay/visual checks not claimed.
- Support point uses get_contact_collider_position, whose world-coordinate contract is documented in [Godot PhysicsDirectBodyState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html#class-physicsdirectbodystate3d-method-get-contact-collider-position) and confirmed by actual floor/box integration.

### Review findings
- R1 — FIXED: floor damage could precede generic cancellation after day/phase invalidation. Session predicate now guards setup and damage, setup follows day transitions, and two regressions invalidate a partially accumulated damage interval without losing HP.

### Owner QA / blockers
Owner QA: play the 3-second preparation/12-second hazard route with movable boxes, perimeter and furniture; inspect zone colors/readability and confirm jump/carry timing. No implementation blocker remains.

---

Зависимости: R09, R14
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 08](../docs/roadmap/08_customer_challenge_framework.md), [ТЗ 17](../docs/roadmap/17_vertical_slice_scenario.md).

## Цель

Создать третий отличный от света и взгляда челлендж, решаемый предметами мира.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [content/entities/props/box.tscn](../content/entities/props/box.tscn)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Подключить опасную поверхность к общему Challenge lifecycle и damage pipeline.
- [x] Разместить безопасные участки и доступные коробки/мебель, позволяющие физически избегать контакта.
- [x] Определить trigger, длительность/условие успеха, escalation и cleanup.
- [x] Отличать реальный контакт с опасным полом от положения над ним на коробке.
- [x] Добавить отдельный профиль клиента; не заменять механику QTE.

## Критерии готовности

- Игрок может пройти/пережить событие с помощью физических предметов.
- Стоя на безопасной коробке, игрок не получает урон за один лишь overlap проекции; после cleanup опасность исчезает.

## Проверки

GUT: правила/урон/cleanup; physics integration пол → коробка → игрок; ручное прохождение безопасным маршрутом. Общие команды и правила завершения — в [README](README.md).

## Границы

Третий challenge обязателен для общего scope, хотя сокращённый сценарий 17 описывает только свет и взгляд. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
