# R13 — Двери, окна, ящики мебели и свет

Status: **OWNER_QA**

## Task state

### Goal
Сделать помещение интерактивным и подготовить физическое окружение для челленджей.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R02, R11.1
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

- Reuse C_Openable / DEF_OpenableMotion / DEF_OpenableAction from R11.1 as the only lock/request/actual-progress authority. Existing C_Door scaffolding remains unused, not a second lock owner.
- Bodies and authored Hinge/Generic6DOF joints own motion/collisions. Shared OpenableJointSolver requests bounded motor velocity/force and measures actual body progress; it never writes a body transform/velocity.
- Preserve existing DoorTemplate/RigidBody3D/Visual/ColShape/HingeJoint3D/ColInteract paths while migrating the action set. Door and Window use hinge motors; Drawer uses constrained linear motors.
- Light circuits use authored group IDs and component state; room lights are engine nodes, not an alternative gameplay authority.

### Current
2026-10-02: Shared Door/Window/Drawer joint servo and warehouse light circuit implemented in the main scene. Existing targeting/highlight/prompt and access contracts reused. Independent read-only review has no material findings, including the revised level cleanup. Next queue task: R14 challenge framework / light condition. Implementation notes: [Environment interactables](../docs/environment_interactables.md).

### Validation
- Godot 4.7.1 / GUT 9.7.1: light_circuit + openable_access + grab_main_scene: 14/14 tests, 123 assertions PASS. After revised cleanup, main-scene grab rerun 1/1, 61 assertions PASS with clean shutdown.
- Strict headless PASS: environment_interactables (1800 frames), environment_interaction (3600 frames), customer_flow (2400 frames), customer_handoff (2400 frames). Covers opposite hinge directions, opening/closure blockers, drawer joint limits/impulse, main-scene collider ancestry and contextual captions, disabled switch prompts, three warehouse lights and independent outdoors.
- Direct main scene headless startup / engine shutdown (120 frames) completes without script/resource/RID errors. Environment certificate-store error remains external to the game.
- Rebuilt warehouse NavigationMesh after frame-clearance change: 122 polygons. NPC NavigationAgent wall-detour regression PASS.
- Project structure and git diff --check PASS. Formatter unavailable; no formatter success claimed.

### Owner QA / blockers
Ручные проверки и результаты игроков: [сценарий QA](../qa_tasks/environment_and_challenges.md).

Игровая приёмка ожидается; перенос не означает успешного прохождения. Реализация и автоматические доказательства остаются в этой задаче.

### Review findings
- R1 (BUG, GECS archetype transition cycles retained scene action/motion resources at teardown): FIXED in project level lifecycle with live-Entity removal and World.purge; addons unchanged. Both scene disposal and actual engine shutdown validated. Customer dialogue fixture still reports two retained script resources; tracked by R12.2/R23.
- R2 (BUG, hash comments in Godot resource text caused subsequent properties to be skipped): FIXED by removing comments from Customer navigation and action resource; authored waypoint tolerance 0.35 and Open priority 1 now apply. Wall-detour smoke rerun PASS.
- R3 (BUG, door frame/window-terminal geometry blocked required endpoints): FIXED with left-beam clearance and outward window direction; real main-scene opening/closure regression PASS.
- Independent reviewer: no additional material findings; read-only, did not run tests.

---

Зависимости: R02, R11.1
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 02](../docs/roadmap/02_core_interaction_and_physics.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 13](../docs/roadmap/13_environment_interactables.md).

## Цель

Сделать помещение интерактивным и подготовить физическое окружение для челленджей.

## Начать здесь

- [content/scenes/main_level.tscn](../content/scenes/main_level.tscn)
- [content/systems/interaction/s_interaction_targeting.gd](../content/systems/interaction/s_interaction_targeting.gd)

Затем прочитать контракты, созданные задачами-зависимостями. Имена новых типов из roadmap — проектируемые контракты, а не утверждение о существующих файлах.

## Работы

- [x] Добавить Door и Window с открыть/закрыть и читаемым состоянием, переиспользуя open/close/access contracts R11.1.
- [x] Добавить Drawer с ограниченным ходом и interaction state поверх translate/prolonged-interaction contracts R11.1.
- [x] Двери и выдвижные элементы должны учитывать препятствия без телепортации через коробку.
- [x] LightSwitch управляет заданными группами света; gameplay-состояние доступно будущим Challenge conditions.
- [x] Использовать единые targeting, highlight и prompts; оставить data-hook для locks/storage.

## Критерии готовности

- Все четыре типа работают через общий interaction framework.
- Коробка физически мешает закрытию двери; удаление/блокировка объекта не оставляет неверный prompt.

## Проверки

GUT: переключения/недоступность/световые группы; integration двери с коробкой и ограничений drawer; ручной walkthrough. Общие команды и правила завершения — в [README](README.md).

## Границы

Без полноценного key/inventory UI и контейнерного stack Inventory: generic access requirement и physical slots уже принадлежат R11.1, а virtual Inventory — R19. Сохранять Godot physics authority, GECS data/behavior boundaries и read-only addons. Выполненные основания переиспользовать, а не создавать заново.

## Первый шаг

Проверить завершение зависимостей по task_history.md и существующим контрактам, затем прочитать указанные исходники и актуализировать WORK.md/CURRENT_WORK.md. При реализации не считать непроверенные пункты выполненными.
