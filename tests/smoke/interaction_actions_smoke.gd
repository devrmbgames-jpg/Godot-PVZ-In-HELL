extends Node
## Real-scene hand routing and Carry/Terminal capture regression.

var _prepared_body: Node3D = null
var _prepared_transform: Transform3D = Transform3D.IDENTITY


class ProbeAction extends DEF_InteractionAction:
	var calls: int = 0


	func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
		return true


	func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
		calls += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var primary_event: InputEventMouseButton = InputEventMouseButton.new()
	primary_event.button_index = MOUSE_BUTTON_LEFT
	primary_event.pressed = true
	assert(primary_event.is_action_pressed(&"action_primary"))
	var secondary_event: InputEventMouseButton = InputEventMouseButton.new()
	secondary_event.button_index = MOUSE_BUTTON_RIGHT
	secondary_event.pressed = true
	assert(secondary_event.is_action_pressed(&"action_secondary"))
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	var level: Node = scene.instantiate()
	add_child(level)
	level.set_physics_process(false)
	for delivery_tick: int in 12:
		await get_tree().physics_frame
		ECS.world.process(1.0 / 60.0, "GamePlay")
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	var scanner: Entity = level.get_node("Entityes/Scanner") as Entity
	var parcel: Entity = level.get_node("Entityes/Parcel_001_03") as Entity
	var terminal: E_Terminal = level.get_node("Entityes/Terminal") as E_Terminal
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	(actor as Node as RigidBody3D).freeze = true
	await _prepare_target(actor, scanner, Vector3(0.0, 0.0, -1.6))
	assert(GrabService.within_pickup_reach(actor, scanner))
	assert(GrabService.pickup_slot(actor, scanner, false) == C_Grabbable.HoldSlot.RIGHT_HAND)
	_drive(actor, true, false, false, false, false)
	assert(GrabService.held_in_slot(actor, C_Grabbable.HoldSlot.RIGHT_HAND) == scanner)
	assert(GrabService.held_object(actor) == scanner)
	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	var primary_probe: ProbeAction = ProbeAction.new()
	primary_probe.slot = DEF_InteractionAction.Slot.PRIMARY
	primary_probe.action_id = &"hand_probe"
	actions.actions = [primary_probe]
	scanner.remove_component(C_InteractionActionSet)
	scanner.add_component(actions)
	_drive(actor, false, false, true, false, false)
	assert(primary_probe.calls == 1, "LMB must use the mapped right hand tool")
	assert(GrabService.held_in_slot(actor, C_Grabbable.HoldSlot.RIGHT_HAND) == scanner)
	_drive(actor, false, false, false, true, false)
	assert(primary_probe.calls == 1, "RMB must address the other hand")
	await _prepare_target(actor, parcel, Vector3(0.0, -0.2, -1.8))
	assert(GrabService.within_pickup_reach(actor, parcel))
	assert(GrabService.try_pickup(actor, parcel, C_Grabbable.HoldSlot.CARRY))
	assert(InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.CARRY)
	_drive(actor, false, false, true, false, false)
	assert(primary_probe.calls == 1, "Carry capture must block hand tool use")
	# Carry owns LMB: it throws Carry, without passing this tick into hand use.
	assert(GrabService.held_in_slot(actor, C_Grabbable.HoldSlot.CARRY) == null)
	assert(GrabService.held_in_slot(actor, C_Grabbable.HoldSlot.RIGHT_HAND) == scanner)
	assert(InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.HANDS)
	_drive(actor, false, false, true, false, false)
	assert(primary_probe.calls == 2, "Hand use must resume after Carry release")
	await _prepare_target(actor, terminal, Vector3(0.0, -0.5, -1.8))
	assert(InteractionTargetingService.find_target(actor, interactor) == terminal)
	_drive(actor, true, false, false, false, false)
	assert(terminal.panel.visible)
	assert(InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.MODAL)
	_drive(actor, false, false, true, false, false)
	assert(primary_probe.calls == 2, "Terminal capture must block hand tool use")
	assert(GrabService.held_in_slot(actor, C_Grabbable.HoldSlot.RIGHT_HAND) == scanner)
	var extra_owner: RefCounted = RefCounted.new()
	var extra_token: int = InteractionControlFocus.acquire(
		actor,
		extra_owner,
		InteractionControlFocus.Priority.PUSH,
	)
	for physics_tick: int in 6:
		await get_tree().physics_frame
	assert(GrabService.held_in_slot(actor, C_Grabbable.HoldSlot.RIGHT_HAND) == scanner)

	terminal.panel.close_panel()
	assert(InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.PUSH)
	assert(
		GrabService.slot_anchor(actor, C_Grabbable.HoldSlot.RIGHT_HAND)
		== actor.get("lowered_right_hand_slot")
	)
	InteractionControlFocus.release(actor, extra_token)
	assert(InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.HANDS)
	_drive(actor, false, false, true, false, false)
	assert(primary_probe.calls == 3, "Terminal close must restore hand tool use")
	_drive(actor, false, false, true, false, false, true)
	assert(GrabService.held_in_slot(actor, C_Grabbable.HoldSlot.RIGHT_HAND) == null)
	assert(primary_probe.calls == 3, "Alt + LMB must throw instead of using")
	assert(
		(InputMap.action_get_events(&"physical_override")[0] as InputEventKey).physical_keycode
		== KEY_ALT
	)
	level.free()
	ECS.world = null
	print("R06.1 interaction hands smoke PASS")
	get_tree().quit()


func _prepare_target(actor: Entity, target: Entity, target_offset: Vector3) -> void:
	if is_instance_valid(_prepared_body):
		var previous: Entity = _prepared_body as Node as Entity
		if GrabService.held_relationship(previous) == null:
			_prepared_body.global_transform = _prepared_transform

	var target_body: Node3D = target as Node as Node3D
	_prepared_body = target_body
	_prepared_transform = target_body.global_transform

	var ray: RayCast3D = GrabService.interaction_raycast(actor)
	target_body.global_position = ray.global_position + target_offset
	await get_tree().physics_frame
	ray.look_at(target_body.global_position)
	ray.force_raycast_update()
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingService.find_target(actor, interactor)


func _drive(
	actor: Entity,
	interact: bool,
	use: bool,
	primary: bool,
	secondary: bool,
	drop: bool,
	physical_override: bool = false,
) -> void:
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	controller.input_tick += 1
	controller.interact_pressed = interact
	controller.use_pressed = use
	controller.action_main_pressed = primary
	controller.action_main = primary
	controller.action_second_pressed = secondary
	controller.action_second_held = secondary
	controller.drop_pressed = drop
	controller.physical_override = physical_override
	ECS.world.process(1.0 / 60.0, "Interaction")
