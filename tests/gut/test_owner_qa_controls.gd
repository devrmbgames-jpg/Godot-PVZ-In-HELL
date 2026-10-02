extends GutTest
## Regression surface for owner QA: sharp look, flat-floor motion and Trader actions.

const MAIN_SCENE: PackedScene = preload("res://content/scenes/main_level.tscn")
const TRADER_SCENE: PackedScene = preload("res://content/entities/commerce/trader.tscn")
const FLOOR_TILE_SIZE: Vector3 = Vector3(8.0, 0.5, 8.0)
const FLOOR_SETTLE_FRAMES: int = 12
const TRAVEL_FRAMES: int = 100
const FLOOR_HEIGHT_TOLERANCE: float = 0.04

var _world: World = null
var _player: E_CharacterBodyPlayer = null
var _floors: Array[StaticBody3D] = []
var _cycle: C_DayCycle = null


func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	for z: float in [-4.0, 4.0]:
		var floor_body: StaticBody3D = StaticBody3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = FLOOR_TILE_SIZE
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		floor_body.add_child(collision)
		floor_body.position = Vector3(0.0, -FLOOR_TILE_SIZE.y / 2.0, z)
		add_child(floor_body)
		_floors.append(floor_body)
	# Use the actual level-authored player, including component overrides.
	# Do not start its World or autosave; this fixture owns isolated physics/support.
	var authored_level: Node3D = MAIN_SCENE.instantiate() as Node3D
	_player = authored_level.get_node("Entityes/Player") as E_CharacterBodyPlayer
	_player.get_parent().remove_child(_player)
	authored_level.free()
	_world.add_entity(_player)
	for child: Node in (_player as Node).find_children("*", "Entity", true, false):
		_world.add_entity(child as Entity, null, false)
	_player.global_position = Vector3(0.0, 0.01, 4.0)
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_Wallet.new(), C_Commerce.new()]
	_world.add_entity(session)
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	for frame: int in FLOOR_SETTLE_FRAMES:
		await get_tree().physics_frame
	await get_tree().process_frame


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	for floor_body: StaticBody3D in _floors:
		floor_body.free()
	_floors.clear()
	await get_tree().process_frame


func test_sharp_turn_reaches_requested_view_in_one_physics_step() -> void:
	var controller: C_Controller = _player.get_component(C_Controller) as C_Controller
	var requested: Vector3 = Vector3(1.0, 0.65, 0.5).normalized()
	controller.direction_look = requested
	controller.direction_motion = Vector3.RIGHT
	await get_tree().physics_frame
	await get_tree().process_frame
	var view_forward: Vector3 = -_player.head_axis_x.global_basis.z
	assert_gt(view_forward.normalized().dot(requested), 0.999, "Fast yaw/pitch is not turn-rate limited or clamped by NPC head limits")
	assert_gt(absf(_player.head_axis_y.rotation.y), 0.01, "Immediate view stays independent of torso turn rate")


func test_flat_tile_seam_does_not_launch_or_stop_player() -> void:
	var controller: C_Controller = _player.get_component(C_Controller) as C_Controller
	controller.direction_motion = Vector3.FORWARD
	controller.direction_look = Vector3.FORWARD
	var initial_height: float = _player.global_position.y
	var highest: float = initial_height
	var lowest: float = initial_height
	var peak_state: String = ""
	for frame: int in TRAVEL_FRAMES:
		await get_tree().physics_frame
		if _player.global_position.y > highest:
			var motion: C_Motion = _player.get_component(C_Motion) as C_Motion
			peak_state = "%s velocity=%s floor=%s normal=%s" % [_player.global_position, (_player as Node as CharacterBody3D).velocity, motion.is_on_floor, motion.floor_normal]
		highest = maxf(highest, _player.global_position.y)
		lowest = minf(lowest, _player.global_position.y)
	assert_gt(4.0 - _player.global_position.z, 6.0, "Player crosses the seam without sticking")
	assert_lt(highest - initial_height, FLOOR_HEIGHT_TOLERANCE, "No unintended flat-floor hop: %s start=%f" % [peak_state, initial_height])
	assert_lt(initial_height - lowest, FLOOR_HEIGHT_TOLERANCE, "No falling through the seam")


func test_trader_interaction_is_discoverable_and_living_npc_cannot_be_grabbed() -> void:
	var trader: Entity = TRADER_SCENE.instantiate() as Entity
	_world.add_entity(trader)
	(trader as Node as Node3D).global_position = _player.global_position + Vector3.FORWARD
	var actions: C_InteractionActionSet = trader.get_component(C_InteractionActionSet) as C_InteractionActionSet
	var action: DEF_TraderAction = actions.actions[0] as DEF_TraderAction
	for phase: C_DayCycle.Phase in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		_cycle.phase = phase
		assert_true(action.is_available(_player, trader, trader), "Trader can explain availability before Evening")
	assert_true(action.allow_interact_fallback, "E can open the same authored action as F")
	assert_false(GrabService.can_pickup(_player, trader, C_Grabbable.HoldSlot.CARRY))
	for frame: int in 2:
		await get_tree().physics_frame
	_cycle.phase = C_DayCycle.Phase.MORNING
	var interactor: C_Interactor = _player.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingService.find_target(_player, interactor)
	interactor.physics_target = InteractionTargetingService.find_physics_target(_player, interactor)
	assert_eq(interactor.target, trader, "Actual head ray reaches the Trader")
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(_player, DEF_InteractionAction.Slot.INTERACT)
	assert_not_null(choice, "E resolves to trading instead of physical pickup")
	if choice != null:
		assert_eq(choice.source, trader)
		assert_true(choice.action is DEF_TraderAction)
	var controller: C_Controller = _player.get_component(C_Controller) as C_Controller
	controller.interact_pressed = true
	InteractionActionResolver.handle_input(_player)
	var opened: bool = false
	for child: Node in _player.get_children():
		if child is CommercePanel:
			opened = true
			(child as CommercePanel).close_panel()
	assert_true(opened, "Ordinary interaction opens the actual Trader panel")
	_cycle.phase = C_DayCycle.Phase.NIGHT
	assert_false(action.is_available(_player, trader, trader))


func test_ground_adhesion_preserves_authored_jump_impulse() -> void:
	_world.add_system(S_Jump.new())
	var controller: C_Controller = _player.get_component(C_Controller) as C_Controller
	controller.action_jump = true
	_world.process(1.0 / 60.0)
	for frame: int in 3:
		await get_tree().physics_frame
	assert_gt((_player as Node as CharacterBody3D).velocity.y, 4.0, "Jump is not canceled by floor adhesion")
	assert_gt(_player.global_position.y, FLOOR_HEIGHT_TOLERANCE)


func test_looking_down_reaches_both_own_belt_slots_without_turning_them_away() -> void:
	var controller: C_Controller = _player.get_component(C_Controller) as C_Controller
	var interactor: C_Interactor = _player.get_component(C_Interactor) as C_Interactor
	var initial_yaw: float = (_player as Node as CharacterBody3D).rotation.y
	for path: String in ["BeltSlotLeft", "BeltSlotRight"]:
		var slot: Entity = _player.get_node(path) as Entity
		var slot_body: Node3D = slot as Node as Node3D
		controller.direction_look = (slot_body.global_position - _player.interaction_ray_cast.global_position).normalized()
		for frame: int in 2:
			await get_tree().physics_frame
		_player.interaction_ray_cast.force_raycast_update()
		assert_eq(InteractionTargetingService.find_target(_player, interactor), slot, "Head ray reaches %s" % path)
		assert_almost_eq((_player as Node as CharacterBody3D).rotation.y, initial_yaw, 0.001, "Belt remains still while aiming down")
