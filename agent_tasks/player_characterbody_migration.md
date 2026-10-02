# Игрок CharacterBody и иммерсивные слоты

Status: **IN_PROGRESS**

## Task state

### Goal
Перенести игрока с RigidBody3D на классический CharacterBody3D, сохранив рабочие взаимодействия/слоты, физические последствия падений и ударов и архив старого игрока.

### Constraints / acceptance
- Владелец явно разрешил миграцию native body type и MCP/engine-проверки 2026-10-03; работа только dev, master read-only, addons не менять.
- CharacterBody владеет transform/velocity через move_and_slide; Components содержат данные, Systems производят intent. NPC пока используют действующий rigid controller.
- Сохранить пути Player/HeadY/HeadX/HeadRoot, Camera/луч/якоря/руки/поясные слоты и существующие действия, relationship ownership, UI/focus, сохранение и health/damage contracts.
- Камера откликается сразу; тело не уводит собственные слоты из прицела при взгляде вниз/в сторону. Контроллер одинаков на main/test.
- Ground RayCast сообщает опору; небольшой импульс RigidBody под ногами задан данными и ограничен, без дублирования обычных столкновений.
- Падение с высоты и быстрый прилетевший RigidBody дают health damage и kinematic bounce/knockback; explicit pending impulse не обнулять обычным locomotion.
- Сохранить старую авторскую Rigid-player сцену/профиль в архиве; NPC и их runtime rigid physics не архивировать как неиспользуемые.

### Milestones
- [x] Зафиксировать текущие player/body/slot и прямые physics/input/damage/transport/persistence контракты; определить общую typed character API.
- [x] Архивировать текущий player и внедрить native CharacterBody контроллер с камерой, ходьбой, прыжком, crouch и Ground RayCast.
- [x] Адаптировать непосредственно зависимые системы/сервисы, rigid опору, контактный урон/отскок, тележку и save/load.
- [x] Обновить main и primitive hosts; выполнить узкие physics/input/slot/damage регрессии и MCP-проверку.
- [ ] Собрать Windows main/test и передать manual feel/full-slice QA владельцу.

### Decisions
Миграция касается игрока. Общие typed head/slot/crouch API нужны Player и rigid NPC; engine-specific движение разделено по native body. Старые данные игрока сохраняются архивной сценой; shared World остаётся единственным.

### Current
Implementation complete; Windows main/test export remains before closing the task. Shared E_PhysicalCharacter API preserves head/hand/slot paths, native player owns move_and_slide, rigid NPC physics stays active. Archived authored player is content/entities/characters/archive/rigid_player.tscn. Contact rebound from either native bridge is queued as data and consumed by the player callback. Collision-safe small-step assistance preserves cart accompaniment.

### Validation
Combined relevant GUT: 46/46, 571 assertions (controls, native physics, both hosts, actual grab pipeline, melee, gaze, snapshot, NPC avoidance). Final native physics rerun after pending-impulse restore guard: 6/6, 33 assertions. Structure/diff PASS. MCP confirmed actual running CharacterBody3D in primitive host and accepted frame-timed forward/jump input; no claim about visual/full-day acceptance. Separate read-only review R2: lost driver step assistance FIXED and rereviewed; actual cart/player 15cm step regression PASS. Formatter unavailable (SKIP). Next: export Windows main/test and confirm actual scene/120-frame startup.

### Owner QA / blockers
Полное ощущение управления, иммерсивные поясные слоты, прыжки/ступени/опора и impact feel — [сценарий владельца](../qa_tasks/owner_qa_fixes.md). Блокеров реализации нет.
