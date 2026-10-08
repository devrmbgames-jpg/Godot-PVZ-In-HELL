extends GutTest
## Проверяет фиксацию молотком, накопление покоя и обратимое восстановление физического состояния.


## Минимальный участник предоставляет сервисам физические опоры и луч тестового окружения.
class Actor extends Entity:
	## Тестовый луч, используемый сервисом наведения.
	var interaction_ray_cast: RayCast3D
	## Тестовая опора переноса груза.
	var hold_anchor: Node3D
	## Тестовая опора правой руки.
	var right_hand_slot: Node3D
	## Тестовая опора левой руки.
	var left_hand_slot: Node3D
	## Опора опущенной правой руки при переносе.
	var lowered_right_hand_slot: Node3D
	## Опора опущенной левой руки при переносе.
	var lowered_left_hand_slot: Node3D


var _world: World
var _actor: Actor
var _controller: C_Controller
var _interactor: C_Interactor
var _hammer: Entity
var _target: Entity
var _body: RigidBody3D
var _config: C_Anchorable


#region Физическое окружение
## Создаёт физический предмет, молоток и игрока с observers хвата и длительных действий.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_GrabLifecycle.new())
	_world.add_observer(O_ProlongedLifecycle.new())
	_actor = Actor.new()
	_actor.component_resources = [
		C_Controller.new(),
		C_Interactor.new(),
		C_GrabControl.new(),
		C_CarryLoad.new(),
		C_Strength.new(),
	]

	var ray: RayCast3D = RayCast3D.new()
	ray.position = Vector3(0, 1, 0)
	ray.target_position = Vector3(0, 0, -3)
	_actor.add_child(ray)
	_actor.interaction_ray_cast = ray
	var anchor: Marker3D = Marker3D.new()
	anchor.position = Vector3(0.6, 1, -0.5)
	_actor.add_child(anchor)
	_actor.hold_anchor = anchor
	_actor.right_hand_slot = anchor
	_actor.left_hand_slot = anchor
	_actor.lowered_right_hand_slot = anchor
	_actor.lowered_left_hand_slot = anchor
	_world.add_entity(_actor)
	_controller = _actor.get_component(C_Controller) as C_Controller
	_interactor = _actor.get_component(C_Interactor) as C_Interactor
	_interactor.collision_mask = 2
	_hammer = _make_hammer()
	_hold_hammer()
	_target = _make_target(Vector3(0, 1, -2))
	_body = GrabService.physical_body(_target)
	_config = _target.get_component(C_Anchorable) as C_Anchorable
	await get_tree().physics_frame
	await get_tree().process_frame
	_interactor.target = _target


## Отменяет сессии и живое владение перед удалением тестового World.
func after_each() -> void:
	if is_instance_valid(_actor):
		ProlongedInteractionService.cancel(_actor)
	if is_instance_valid(_world):
		for entity: Entity in _world.entities.duplicate():
			GrabService.entity_unavailable(entity)
			ProlongedInteractionService.entity_unavailable(entity)
		_world.free()
	ECS.world = null


func _make_hammer() -> Entity:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_GrabbableBody)
	body.position = Vector3(1, 1, -1)
	body.gravity_scale = 0.0
	body.collision_layer = 8
	body.collision_mask = 29
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.1
	collision.shape = shape
	body.add_child(collision)

	var hammer: Entity = body as Node as Entity
	var grabbable: C_Grabbable = C_Grabbable.new()
	grabbable.allowed_hand_slots = 6
	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	actions.actions = [DEF_AnchorAction.new()]
	hammer.component_resources = [grabbable, C_Interactable.new(), C_AnchorTool.new(), actions]
	_world.add_entity(hammer)
	return hammer


func _make_target(location: Vector3) -> Entity:
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_GrabbableBody)
	body.position = location
	body.gravity_scale = 0.0
	body.collision_layer = 2
	body.collision_mask = 29
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.5
	collision.shape = shape
	body.add_child(collision)
	var target: Entity = body as Node as Entity
	var anchorable: C_Anchorable = C_Anchorable.new()
	anchorable.minimum_rest_seconds = 0.5
	anchorable.maximum_linear_speed = 0.1
	anchorable.maximum_angular_speed = 0.1

	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	actions.actions = [DEF_UnfixAnchorAction.new()]
	target.component_resources = [anchorable, C_Interactable.new(), actions]
	_world.add_entity(target)
	return target


func _hold_hammer() -> void:
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.RIGHT_HAND
	_hammer.add_relationship(Relationship.new(grip, _actor))
	assert_eq(GrabService.held_in_slot(_actor, C_Grabbable.HoldSlot.RIGHT_HAND), _hammer)


func _stabilize(seconds: float = 0.5) -> void:
	InteractionPhysicsFixture.anchor(_target, seconds)


#endregion

#region Инструмент и обратимая фиксация
## Авторский молоток проигрывает крепление без боевого урона; бросок сразу отменяет анимацию.
func test_authored_hammer_fastens_instead_of_attacking_and_plays_swing_without_damage() -> void:
	GrabService.release(_actor, _hammer)
	_hammer = (load("res://content/entities/tools/hammer.tscn") as PackedScene).instantiate() as Entity
	_world.add_entity(_hammer)
	(_hammer as Node as RigidBody3D).gravity_scale = 0.0
	(_hammer as Node as Node3D).global_position = _actor.right_hand_slot.global_position
	_actor.add_component(C_Combat.new())
	var health: C_Health = C_Health.new()
	health.value = 100.0
	health.current = 100.0
	_target.add_component(health)
	_hold_hammer()
	_stabilize()

	var choice: InteractionActionChoice = InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.PRIMARY)
	assert_not_null(choice)
	if choice != null:
		assert_true(choice.action is DEF_AnchorAction)
	_controller.action_main_pressed = true
	_controller.input_tick += 1
	InteractionInputFixture.advance(_actor)
	assert_true(_body.freeze)
	assert_eq((_actor.get_component(C_Combat) as C_Combat).phase, C_Combat.Phase.READY)

	var animation: AnimationPlayer = _hammer.get_node("AttackAnimation") as AnimationPlayer
	assert_eq(animation.current_animation, &"strike")
	for frame: int in 8:
		await get_tree().physics_frame
	var head: Node3D = _hammer.get_node("Head") as Node3D
	assert_gt(head.position.y, 0.4, "Fastening has visible overhead swing")
	assert_eq(health.current, 100.0, "Tool animation never schedules weapon damage")
	GrabService.release(_actor, _hammer)
	assert_false(animation.is_playing())
	assert_eq(head.position, Vector3(0.0, 0.18, 0.0), "Drop cancels tool presentation immediately")


func _drive_input(primary_pressed: bool, use_pressed: bool, use_held: bool, delta: float = 0.0) -> void:
	_controller.action_main_pressed = primary_pressed
	_controller.action_main = primary_pressed
	_controller.use_pressed = use_pressed
	_controller.use_held = use_held
	_controller.input_tick += 1
	InteractionInputFixture.advance(_actor, delta)
	_controller.action_main_pressed = false
	_controller.use_pressed = false


## Покой накапливается непрерывно только при малой скорости и отсутствии владельца управления.
func test_stability_requires_continuous_low_motion_and_no_control_owner() -> void:
	_body.linear_velocity = Vector3(0.2, 0, 0)
	InteractionPhysicsFixture.anchor(_target, 0.3)
	assert_eq(_config.stable_seconds, 0.0)
	_body.linear_velocity = Vector3.ZERO
	InteractionPhysicsFixture.anchor(_target, 0.3)
	assert_almost_eq(_config.stable_seconds, 0.3, 0.0001)
	var push: Relationship = Relationship.new(R_PushedBy.new(), _actor)
	_target.add_relationship(push)
	InteractionPhysicsFixture.anchor(_target, 0.3)
	assert_eq(_config.stable_seconds, 0.0)
	_target.remove_relationship(push)
	InteractionPhysicsFixture.anchor(_target, 0.5)
	assert_almost_eq(_config.stable_seconds, 0.5, 0.0001)


## Авторский freeze сам по себе не означает фиксацию игроком.
func test_authored_frozen_body_is_never_inferred_as_player_anchor() -> void:
	_config.stable_seconds = 10.0
	_body.freeze = true
	assert_false(AnchoringService.can_anchor(_actor, _hammer, _target))
	assert_false(AnchoringService.is_player_anchored(_target))
	_body.freeze = false


## Основное действие фиксирует предмет и блокирует его захват.
func test_primary_hammer_action_anchors_and_blocks_grab() -> void:
	_stabilize()
	assert_true(AnchoringService.can_anchor(_actor, _hammer, _target))
	_drive_input(true, false, false)
	assert_true(AnchoringService.is_player_anchored(_target))
	assert_true(_body.freeze)
	assert_eq(_body.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)
	assert_false(GrabService.can_pickup(_actor, _target, C_Grabbable.HoldSlot.CARRY))


## Длительное открепление по F возвращает точные параметры тела из снимка перед фиксацией.
func test_snapshot_restores_exact_physics_state_after_prolonged_f_unfix() -> void:
	_body.can_sleep = false
	_body.sleeping = false
	_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_body.linear_velocity = Vector3(0.02, 0, 0)
	_body.angular_velocity = Vector3(0, 0.03, 0)
	var expected_linear: Vector3 = _body.linear_velocity
	var expected_angular: Vector3 = _body.angular_velocity
	_stabilize()
	_drive_input(true, false, false)
	assert_true(_body.freeze)

	_controller.action_main = false
	assert_null(
		InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.INTERACT),
		"Unfix is F-only and must not leak into the E fallback",
	)
	assert_not_null(
		InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.USE),
		"F must resolve the prolonged unfix action",
	)
	_drive_input(false, true, true)
	assert_not_null(ProlongedInteractionService.session(_actor))

	var half_duration: float = ProlongedInteractionService.active_progress(_actor).timing.duration_seconds * 0.5
	_drive_input(false, false, true, half_duration)
	assert_true(AnchoringService.is_player_anchored(_target))
	_drive_input(false, false, true, half_duration)
	assert_false(AnchoringService.is_player_anchored(_target))
	assert_false(_body.freeze)
	assert_eq(_body.freeze_mode, RigidBody3D.FREEZE_MODE_KINEMATIC)
	assert_false(_body.can_sleep)
	assert_false(_body.sleeping)
	assert_eq(_body.linear_velocity, expected_linear)
	assert_eq(_body.angular_velocity, expected_angular)

	_controller.use_held = false
	_controller.input_tick += 1
	InteractionInputFixture.advance(_actor, 0.0)
	assert_null(ProlongedInteractionService.session(_actor))


## Молоток в неподходящей руке не предлагает основное действие крепления.
func test_wrong_hand_tool_does_not_offer_primary_fix() -> void:
	GrabService.release(_actor, _hammer)
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.LEFT_HAND
	_hammer.add_relationship(Relationship.new(grip, _actor))
	_stabilize()
	assert_false(AnchoringService.can_anchor(_actor, _hammer, _target))
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(
		_actor,
		DEF_InteractionAction.Slot.PRIMARY,
	)
	assert_null(choice)

#endregion
