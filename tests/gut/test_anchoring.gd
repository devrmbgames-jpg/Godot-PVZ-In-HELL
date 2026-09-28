extends GutTest


class Actor extends Entity:
	var interaction_ray_cast: RayCast3D
	var hold_anchor: Node3D
	var right_hand_slot: Node3D
	var left_hand_slot: Node3D
	var lowered_right_hand_slot: Node3D
	var lowered_left_hand_slot: Node3D


var _world: World
var _actor: Actor
var _controller: C_Controller
var _interactor: C_Interactor
var _hammer: Entity
var _target: Entity
var _body: RigidBody3D
var _config: C_Anchorable


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
	AnchoringService.update_stability(_target, _config, seconds)


func _drive_input(primary_pressed: bool, use_pressed: bool, use_held: bool, delta: float = 0.0) -> void:
	_controller.action_main_pressed = primary_pressed
	_controller.action_main = primary_pressed
	_controller.use_pressed = use_pressed
	_controller.use_held = use_held
	_controller.input_tick += 1
	InteractionActionResolver.handle_drive_input(_actor, delta)
	_controller.action_main_pressed = false
	_controller.use_pressed = false


func test_stability_requires_continuous_low_motion_and_no_control_owner() -> void:
	_body.linear_velocity = Vector3(0.2, 0, 0)
	AnchoringService.update_stability(_target, _config, 0.3)
	assert_eq(_config.stable_seconds, 0.0)
	_body.linear_velocity = Vector3.ZERO
	AnchoringService.update_stability(_target, _config, 0.3)
	assert_almost_eq(_config.stable_seconds, 0.3, 0.0001)
	var push: Relationship = Relationship.new(R_PushedBy.new(), _actor)
	_target.add_relationship(push)
	AnchoringService.update_stability(_target, _config, 0.3)
	assert_eq(_config.stable_seconds, 0.0)
	_target.remove_relationship(push)
	AnchoringService.update_stability(_target, _config, 0.5)
	assert_almost_eq(_config.stable_seconds, 0.5, 0.0001)


func test_authored_frozen_body_is_never_inferred_as_player_anchor() -> void:
	_config.stable_seconds = 10.0
	_body.freeze = true
	assert_false(AnchoringService.can_anchor(_actor, _hammer, _target))
	assert_false(AnchoringService.is_player_anchored(_target))
	_body.freeze = false


func test_primary_hammer_action_anchors_and_blocks_grab() -> void:
	_stabilize()
	assert_true(AnchoringService.can_anchor(_actor, _hammer, _target))
	_drive_input(true, false, false)
	assert_true(AnchoringService.is_player_anchored(_target))
	assert_true(_body.freeze)
	assert_eq(_body.freeze_mode, RigidBody3D.FREEZE_MODE_STATIC)
	assert_false(GrabService.can_pickup(_actor, _target, C_Grabbable.HoldSlot.CARRY))


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
	_drive_input(false, true, true)
	assert_not_null(ProlongedInteractionService.session(_actor))
	_drive_input(false, false, true, 0.75)
	assert_true(AnchoringService.is_player_anchored(_target))
	_drive_input(false, false, true, 0.75)
	assert_false(AnchoringService.is_player_anchored(_target))
	assert_false(_body.freeze)
	assert_eq(_body.freeze_mode, RigidBody3D.FREEZE_MODE_KINEMATIC)
	assert_false(_body.can_sleep)
	assert_false(_body.sleeping)
	assert_eq(_body.linear_velocity, expected_linear)
	assert_eq(_body.angular_velocity, expected_angular)

	_controller.use_held = false
	_controller.input_tick += 1
	InteractionActionResolver.handle_drive_input(_actor, 0.0)
	assert_null(ProlongedInteractionService.session(_actor))


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
