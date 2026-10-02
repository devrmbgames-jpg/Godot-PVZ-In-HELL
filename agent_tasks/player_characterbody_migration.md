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
- [ ] Зафиксировать текущие player/body/slot и прямые physics/input/damage/transport/persistence контракты; определить общую typed character API.
- [ ] Архивировать текущий player и внедрить native CharacterBody контроллер с камерой, ходьбой, прыжком, crouch и Ground RayCast.
- [ ] Адаптировать непосредственно зависимые системы/сервисы, rigid опору, контактный урон/отскок, тележку и save/load.
- [ ] Обновить main и primitive hosts; выполнить узкие physics/input/slot/damage регрессии и MCP-проверку.
- [ ] Собрать Windows main/test и передать manual feel/full-slice QA владельцу.

### Decisions
Миграция касается игрока. Общие typed head/slot/crouch API нужны Player и rigid NPC; engine-specific движение разделено по native body. Старые данные игрока сохраняются архивной сценой; shared World остаётся единственным.

### Current
Начат аудит. Прямые typed потребители E_RigidBodyCharacter: S_Crouch/S_CrouchPresentation, CombatGeometry, GazeTrackingService, CustomerFlowService; GrabService уже предоставляет anchors через Entity API. Jump пишет pending impulse; C_RigidBody сейчас служит marker для crouch. NPC avoidance завершён и остаётся совместимым с rigid NPC. MCP подтвердил Godot 4.7.1, открытый main_level, editor ready, игра остановлена. Следующий шаг: завершить минимальный аудит body-dependent transport/impact/snapshot contracts и внедрить общий character API + новый player.

### Validation
До миграции: 14/14 GUT, 56 assertions для NPC avoidance + rigid player/input; эти доказательства исторические. После изменения нужны новые реальные CharacterBody regressions и relevant headless/MCP smoke. Rendered проверки разрешены новым запросом владельца; full-day приёмка остаётся игрокам.

### Owner QA / blockers
Полное ощущение управления, иммерсивные поясные слоты, прыжки/ступени/опора и impact feel — [сценарий владельца](../qa_tasks/owner_qa_fixes.md). Блокеров реализации нет.
