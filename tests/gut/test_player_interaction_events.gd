extends GutTest
## Проверяет события владельцев фактических переходов и их реальные GECS-подписки.

## Записывает настоящие опубликованные переходы для проверки атрибуции и однократности.
class Probe extends Observer:
	## Полученные события текущего теста в порядке публикации.
	var events: Array[PlayerInteractionEvent] = []

	## Подписывается на общий канал фактических действий игрока.
	func query() -> QueryBuilder:
		return q.on_event(PlayerInteractionEvent.EVENT)

	## Сохраняет только типизированный переход соответствующего объекта.
	func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
		var transition: PlayerInteractionEvent = payload as PlayerInteractionEvent
		if transition != null and transition.object == entity:
			events.append(transition)


var _root: Node3D
var _world: World
var _actor: E_RigidBodyCharacter
var _probe: Probe


#region Окружение и подписчик
## Создаёт игрока, реальный observer событий и объекты с сохраняемыми владельцами.
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	_world.add_observer(O_GrabLifecycle.new())
	_probe = Probe.new()
	_world.add_observer(_probe)

	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.name = "Actor"
	body.set_script(load("res://content/entities/characters/e_rigid_body_character.gd"))
	_actor = body as Node as E_RigidBodyCharacter
	var anchor: Marker3D = Marker3D.new()
	anchor.position.y = 1.0
	body.add_child(anchor)
	_actor.hold_anchor = anchor

	var ray: RayCast3D = RayCast3D.new()
	ray.position.y = 1.0
	ray.target_position = Vector3(0, 0, -3)
	ray.enabled = true
	body.add_child(ray)
	_actor.interaction_ray_cast = ray
	_actor.component_resources = [C_PlayerInputController.new(), C_Controller.new(), C_Interactor.new(), C_GrabControl.new(), C_CarryLoad.new(), C_Strength.new()]
	_root.add_child(body)
	_actor.owner = _root
	_world.add_entity(_actor, null, false)

	var session: Entity = Entity.new()
	session.name = "Session"
	session.component_resources = [C_DayCycle.new()]
	_root.add_child(session)
	session.owner = _root
	_world.add_entity(session, null, false)


## Удаляет World и даёт завершиться отложенной очистке дерева.
func after_each() -> void:
	_world.purge(false)
	_root.free()
	ECS.world = null
	await get_tree().process_frame


func _door() -> E_Door:
	var door: E_Door = (load("res://content/entities/doors/door_template.tscn") as PackedScene).instantiate() as E_Door
	_root.add_child(door)
	door.owner = _root
	_world.add_entity(door, null, false)
	door.set_physics_process(false)
	door.door_root.freeze = true
	return door


func _parcel() -> Entity:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_GrabbableBody)
	body.position = Vector3(0, 1, -1)
	body.gravity_scale = 0.0
	var parcel: Entity = body as Node as Entity
	var identity: C_Package = C_Package.new()
	identity.package_id = "events/parcel"
	parcel.component_resources = [identity, C_Interactable.new(), C_Grabbable.new()]

	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	body.add_child(collider)
	_world.add_entity(parcel)
	return parcel


#endregion

#region Фактические переходы и атрибуция
## Открытие и закрытие панели дают по одному событию и корректно возвращают ввод.
func test_terminal_reports_actual_visibility_and_releases_capture_once() -> void:
	var terminal: E_Terminal = (load("res://content/entities/stations/terminal.tscn") as PackedScene).instantiate() as E_Terminal
	_world.add_entity(terminal)
	terminal.open_for(_actor)
	terminal.open_for(_actor)
	assert_true(terminal.is_panel_open())
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.MODAL)
	assert_eq(_probe.events.size(), 1)
	assert_eq(_probe.events[0].kind, PlayerInteractionEvent.Kind.TERMINAL_OPENED)
	assert_eq(_probe.events[0].actor_id, _actor.id)
	assert_eq(_probe.events[0].object_id, terminal.id)
	terminal.close_panel()
	terminal.close_panel()
	assert_false(terminal.is_panel_open())
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)
	assert_eq(_probe.events.size(), 2)
	assert_eq(_probe.events[1].kind, PlayerInteractionEvent.Kind.TERMINAL_CLOSED)


## Событие соответствует принятому хвату и реальному отпусканию; удаление предмета не означает размещение игроком.
func test_parcel_reports_accepted_grip_and_real_release_not_repeat_or_failure() -> void:
	var parcel: Entity = _parcel()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(GrabService.try_pickup(_actor, parcel))
	assert_eq(_probe.events.size(), 1)
	assert_eq(_probe.events[0].kind, PlayerInteractionEvent.Kind.PARCEL_PICKED)
	assert_eq(_probe.events[0].package_id, "events/parcel")
	assert_false(GrabService.try_pickup(_actor, parcel))
	assert_eq(_probe.events.size(), 1)
	GrabService.release(_actor, parcel)
	GrabService.release(_actor, parcel)
	assert_null(GrabService.held_relationship(parcel))
	assert_null(GrabService.held_object(_actor))
	assert_eq(_probe.events.size(), 2)
	assert_eq(_probe.events[1].kind, PlayerInteractionEvent.Kind.PARCEL_PLACED)
	assert_true(GrabService.try_pickup(_actor, parcel))
	_world.remove_entity(parcel)
	assert_eq(_probe.events.size(), 3, "Removal is not a player placement")


## Дверь публикует достижение физического края, а не просьбу открыть или промежуточную долю.
func test_door_reports_native_endpoint_not_request_blocked_fraction_or_jitter() -> void:
	var door: E_Door = _door()
	var state: C_Openable = door.get_component(C_Openable) as C_Openable
	state.locked = true
	assert_false(OpenableService.request(_actor, door, OpenableService.Operation.OPEN))
	assert_eq(_probe.events.size(), 0)
	state.locked = false
	assert_true(OpenableService.request(_actor, door, OpenableService.Operation.OPEN))
	assert_eq(_probe.events.size(), 0)
	door.door_root.transform = OpenableService.local_transform(state.motion, 0.5)
	OpenableJointSolver.step(door, door.door_root, door.hinge_joint, null)
	assert_almost_eq(state.actual_fraction, 0.5, 0.001)
	assert_eq(_probe.events.size(), 0)
	door.door_root.transform = OpenableService.local_transform(state.motion, 0.99)
	OpenableJointSolver.step(door, door.door_root, door.hinge_joint, null)
	OpenableJointSolver.step(door, door.door_root, door.hinge_joint, null)
	assert_eq(_probe.events.size(), 1)
	assert_eq(_probe.events[0].kind, PlayerInteractionEvent.Kind.DOOR_OPENED)
	assert_true(OpenableService.request(_actor, door, OpenableService.Operation.CLOSE))
	assert_eq(_probe.events.size(), 1)
	door.door_root.transform = OpenableService.local_transform(state.motion, 0.01)
	OpenableJointSolver.step(door, door.door_root, door.hinge_joint, null)
	OpenableJointSolver.step(door, door.door_root, door.hinge_joint, null)
	assert_eq(_probe.events.size(), 2)
	assert_eq(_probe.events[1].kind, PlayerInteractionEvent.Kind.DOOR_CLOSED)


## Отменённое, загруженное или перенесённое через ночь намерение не воспроизводит старое событие.
func test_superseded_or_restored_pending_door_intent_never_replays() -> void:
	var door: E_Door = _door()
	var state: C_Openable = door.get_component(C_Openable) as C_Openable
	assert_true(OpenableService.request(_actor, door, OpenableService.Operation.OPEN))
	assert_true(OpenableService.request(_actor, door, OpenableService.Operation.CLOSE))
	OpenableService.report_fraction(state, 0.0, door)
	assert_eq(_probe.events.size(), 0, "Canceled opening did not move the leaf")
	assert_true(OpenableService.request(_actor, door, OpenableService.Operation.OPEN))

	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	OpenableService.report_fraction(state, 1.0, door)
	assert_eq(_probe.events.size(), 0, "Loaded motion cannot replay its original player's request")
	state.actual_fraction = 0.0
	state.requested_open = false
	assert_true(OpenableService.request(_actor, door, OpenableService.Operation.OPEN))
	NightResetService.reset()
	OpenableService.report_fraction(state, 1.0, door)
	assert_eq(_probe.events.size(), 0, "Pending attribution does not cross Night reset")


## Действие NPC и принудительная очистка хвата не публикуют событие действия игрока.
func test_npc_and_forced_release_do_not_emit_player_action() -> void:
	var parcel: Entity = _parcel()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(GrabService.try_pickup(_actor, parcel))
	GrabService.release(_actor, parcel, false)
	assert_eq(_probe.events.size(), 1)
	assert_true(GrabService.try_pickup(_actor, parcel))
	(parcel as Node as RigidBody3D).freeze = true
	GrabService.handle_input(_actor)
	assert_null(GrabService.held_relationship(parcel))
	assert_eq(_probe.events.size(), 2, "Invalid-grip input cleanup is not a player placement")
	(parcel as Node as RigidBody3D).freeze = false
	_actor.remove_component(C_PlayerInputController)
	assert_true(GrabService.try_pickup(_actor, parcel))
	GrabService.release(_actor, parcel)

	var door: E_Door = _door()
	var state: C_Openable = door.get_component(C_Openable) as C_Openable
	assert_true(OpenableService.request(_actor, door, OpenableService.Operation.OPEN))
	OpenableService.report_fraction(state, 1.0, door)
	assert_eq(_probe.events.size(), 2, "NPC actions are not player events")

#endregion
