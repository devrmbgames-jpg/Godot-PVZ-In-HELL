# Физическое взаимодействие

Механика подключена в [main_level.tscn](../content/scenes/main_level.tscn). Актуальные кнопки и таблица E/F — в [controls.md](controls.md).

## Авторинг и владение

Статические Components и действия задаются через scene `component_resources`: Player, Scanner, Package, Terminal, DaySession, станции, приёмка и PushCart. Единственное project-owned исключение `define_components()` — spawn-specific `C_Package` с устойчивым ID и переданной definition. Состояние/целостность Package авторятся в сцене; спавнер копирует только индивидуальный grab-профиль. Изменяемые scene-ресурсы с контейнерами изолированы между экземплярами.

Источник владения — `предмет --C_HeldBy--> holder`. `C_HeldBy.slot` выбирается при pickup: CARRY, RIGHT_HAND или LEFT_HAND. Один объект имеет одного holder; каждый слот вмещает один объект. Holder может одновременно держать три предмета.

`C_Grabbable.allowed_hand_slots=0` означает Carry-only; флаги Right=2 и Left=4 задают разрешённые руки. Scanner разрешает обе. `C_GrabControl.held_carry/held_right/held_left` — только производные индексы. `S_Grab.held_in_slot()` проверяет relation; агрегатный `held_object()` оставлен для single-object callers и не определяет вместимость.

`S_Grab.try_pickup(holder, target, slot, replace)` полностью проверяет slot/body/ownership/LOS перед освобождением заменяемого предмета. Relationship добавляется на синхронной command boundary. `release` сохраняет инерцию; `throw` сначала освобождает связь и добавляет импульс `direction × mass × throw_velocity`.

## Физика Grab

RigidBody владеет transform/velocity. Для authored `E_GrabbableBody` существующий `_integrate_forces` продолжает передавать state в общий `GrabPhysicsSolver`. Обычный `RigidBody3D` **вообще без script/Entity/Components** может использовать тот же Carry: `S_InteractionTargeting` хранит первый rigid collider в `C_Interactor.physics_target`, а при фактическом pickup `PhysicsGrabTarget` создаёт лёгкий runtime GECS proxy с `C_PhysicsBodyRef`. Сам исходный body не получает script и не становится gameplay Entity.

`C_HeldBy` остаётся единственным ownership-authority и хранится на Entity либо на таком proxy. Для scriptless/foreign rigid body `S_Grab` применяет `GrabPhysicsSolver` перед physics step через обычные forces/angular velocity; callback чужого body не подменяется. Нет reparent, freeze или teleport. Удаление исходного body удаляет proxy и освобождает Carry.

По умолчанию raw rigid body является **Carry-only** и использует `GrabControlProfile` со стандартными коэффициентами. `C_Grabbable` теперь является authored override для hand slots, throw/rotation/hold tuning и Carry penalties, а не обязательным маркером физической поднимаемости. `C_GrabControl.max_carry_mass` (80 кг по умолчанию) задаёт предел generic Carry; группа `no_carry` является Inspector-friendly opt-out для конкретного RigidBody. Freeze и невалидная масса также запрещают generic pickup.

Нет переподчинения, заморозки или телепортации тела. Перенос использует ограниченную силу пружины с компенсацией гравитации; вращение — angular-velocity servo по кратчайшей quaternion-ошибке.

RayCast следует за HeadX, обновляется на границе команды и исключает holder и все три удерживаемых объекта. Первый collider остаётся авторитетом LOS. `O_GrabLifecycle` обслуживает исключения столкновений с holder, can_sleep, cache и очистку. Удаление/отключение участника, смерть, заморозка предмета и чрезмерное расстояние завершают владение; world removal не требует удаления Node.

`C_CarryLoad` относится только к Carry: его множители не меняют исходные C_Motion speed/acceleration и не применяются к hand-items. Профили посылок 5/30/80 кг сохраняют отдельные data-driven штрафы и throw velocity. Стандартная дистанция Carry — 1,25 м; предмет может её переопределить.

## Capture и anchors

`InteractionControlFocus` хранит в C_GrabControl единый registry уникальных токенов. `acquire(actor, owner, priority)` возвращает новый token даже для повторного owner; `release(actor, token)` снимает только его. WeakRef позволяет убрать уничтоженного owner. Приоритет: MODAL > PUSH > CARRY > HANDS.

Carry relation, Push relation и каждый Terminal владеют своими токенами. LEFT/RIGHT остаются owned во время capture, но выбирают authored LoweredRightHand/LoweredLeftHand вместо ArmRSlot/ArmLSlot. Обычные authored transforms не меняются. После последнего release возвращаются прежние anchors и mapping без pickup.

При смене anchor сбрасывается оценка его скорости; даётся 0,5 с на физический переход. Пока руки опущены, допустимое расстояние учитывает смещение нормального anchor к lowered. Это предотвращает ложный разрыв при опускании, сохраняя проверку реального чрезмерного удаления.

## Ввод и вращение

`S_PlayerInput` — единственный writer input edges, move_axis и look_delta. `InteractionActionResolver` исполняется через command buffer S_Grab; input_tick предотвращает повторную обработку. E/F/G ветки исключают одновременные действия рук. Снимок focus не позволяет броску Carry передать тот же input ниже по приоритету.

PRIMARY в `C_InteractionActionSet` — use-action инструмента. Resolver отображает ЛКМ/ПКМ на физические руки через swap_hand_controls; занятая рука резервирует свою кнопку даже без доступной цели. Alt бросает mapped hand. R вращает первый разрешённый предмет в порядке primary → secondary только без конфликтующего use-input. Carry использует ПКМ. Все подсказки читает HUD из C_Interactor.prompt_text; HUD не владеет gameplay.

`manual_rotation_enabled` отключает ручное вращение и его prompt. FREE применяет pitch/yaw, Y_ONLY меняет только yaw rotation offset. `reset_rotation_on_pickup` задаёт identity offset относительно выбранного anchor; без него сохраняется текущая относительная ориентация. Scanner запрещает вращение и сбрасывает offset; Bucket имеет Y_ONLY и reset.

G short-release освобождает один слот Carry → Left → Right. Порог `drop_long_press_seconds` настраивается в Inspector (0,45 с); long-press выставляет placeholder-состояние без short-drop. Полного radial menu нет.

## Push

`PushCart` имеет C_Pushable и C_Interactable, но не C_Grabbable. Authority — отдельная связь `cart --C_PushedBy--> actor`; C_PushControl.pushed_object — проверяемый reverse cache. `DEF_PushAction` начинает/заканчивает Push через общий resolver; `O_PushLifecycle` обслуживает world/tree cleanup и can_sleep.

W задаёт фиксированную forward_speed, A/D — turn_speed в радианах/с; скорость не зависит от mouse sensitivity. S/E завершает режим, задней тяги нет. `S_Push.integrate_cart` задаёт скорости только на физическом шаге, сохраняя gravity/collision response. `S_Motion` передаёт планарное движение игрока в `S_Push.integrate_actor`: физическая скорость ведёт его за рукоятью с ограниченной коррекцией, без записи transform.

Тележка должна оставаться впереди игрока, в focus_distance и без препятствия между actor и тележкой. Недоступность, потеря фронтального focus/дистанции/LOS безопасно снимают Push. MODAL временно останавливает мотор, сохраняя Push relation/token; закрытие UI не поднимает руки, если Push/Carry ещё активен. Полноценного vehicle framework нет.

Порядок тика: Input → Interaction (targeting → Push validation → Grab/resolver) → Physics → GamePlay. Физические callbacks тел отдельно применяют solver.

## Проверки

```text
python utils/validate_project_structure.py
<godot> --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/gut -gexit
<godot> --headless --path . res://tests/smoke/interaction_actions_smoke.tscn --quit-after 180
<godot> --headless --path . res://tests/smoke/receiving_scan_smoke.tscn --quit-after 360
```

Для smoke необходим явный PASS marker. Существующий `test_s_grab.gd` дополнительно содержит шесть regression cases для полностью scriptless `RigidBody3D`: separate physics targeting, lazy proxy pickup через E, mass/`no_carry` policy, inertia/collision cleanup, force-based follow без teleport и cleanup при удалении исходного body. Остальные проверки покрывают слоты, replacement, capture nesting, mapped input, G, rotation policies, LOS, реальные силы/вращение, Push-скорости, стену и player-follow. Проверка main scene подтверждает, что стартовая тележка не пересекает геометрию.

Автоматические проверки не заменяют ручную оценку удобства камеры, геймпада и тесных поворотов тележки.
