extends Node


class ProbeAction extends InteractionAction:
	var calls: int = 0
	var available: bool = true


	func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
		return available


	func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
		calls += 1


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var use_key: InputEventKey = InputEventKey.new()
	use_key.physical_keycode = KEY_F
	use_key.pressed = true
	assert(use_key.is_action_pressed(&"use"))
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	var level: Node = scene.instantiate()
	add_child(level)
	level.set_physics_process(false)
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	var tool: Entity = level.get_node("Entityes/Box3") as Entity
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
	var ray: RayCast3D = S_Grab.interaction_raycast(actor)
	ray.look_at((tool as Node as Node3D).global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(S_Grab.try_pickup(actor, tool))
	var tool_actions: C_InteractionActions = C_InteractionActions.new()
	var scan: ProbeAction = ProbeAction.new()
	scan.slot = InteractionAction.Slot.PRIMARY
	scan.action_id = &"scan"
	scan.caption = "Сканировать"
	var draw: ProbeAction = ProbeAction.new()
	draw.slot = InteractionAction.Slot.SECONDARY
	draw.continuous = true
	draw.caption = "Рисовать"
	tool_actions.actions = [scan, draw]
	tool.add_component(tool_actions)
	controller.input_tick = 1
	controller.action_main_pressed = true
	controller.action_second_held = true
	S_Grab.handle_input(actor)
	S_Grab.handle_input(actor)
	assert(scan.calls == 1 and draw.calls == 1)
	assert(controller.action_main_pressed)
	assert(S_Grab.held_object(actor) == tool and not control.rotation_active)
	assert("Сканировать" in interactor.prompt_text and "Alt + ЛКМ" in interactor.prompt_text)
	assert(not InteractionActions.wants_rotation(actor, controller))
	scan.available = false
	controller.input_tick += 1
	S_Grab.handle_input(actor)
	assert(scan.calls == 1 and S_Grab.held_object(actor) == tool)
	assert("Сканировать" not in interactor.prompt_text)
	controller.physical_override = true
	controller.action_main_pressed = false
	controller.input_tick += 1
	S_Grab.handle_input(actor)
	assert(control.rotation_active and draw.calls == 2)
	controller.action_second_held = false
	controller.action_main_pressed = true
	controller.input_tick += 1
	S_Grab.handle_input(actor)
	assert(S_Grab.held_object(actor) == null and scan.calls == 1)
	var actor_actions: C_InteractionActions = C_InteractionActions.new()
	var fallback: ProbeAction = ProbeAction.new()
	fallback.slot = InteractionAction.Slot.PRIMARY
	actor_actions.actions = [fallback]
	actor.add_component(actor_actions)
	controller.input_tick += 1
	S_Grab.handle_input(actor)
	assert(fallback.calls == 1)
	var use_action: ProbeAction = ProbeAction.new()
	use_action.slot = InteractionAction.Slot.USE
	use_action.action_id = &"b"
	var preferred: ProbeAction = ProbeAction.new()
	preferred.slot = InteractionAction.Slot.USE
	preferred.action_id = &"a"
	actor_actions.actions = [use_action, preferred]
	controller.action_main_pressed = false
	controller.use_pressed = true
	controller.input_tick += 1
	S_Grab.handle_input(actor)
	assert(preferred.calls == 1 and use_action.calls == 0)
	tool.add_relationship(Relationship.new(C_HeldBy.new(), actor))
	assert(S_Grab.held_object(actor) == tool)
	ECS.world.remove_entity(tool)
	controller.action_second_held = true
	assert(not InteractionActions.wants_rotation(actor, controller))
	assert(S_Grab.held_object(actor) == null)
	assert(
		(InputMap.action_get_events(&"physical_override")[0] as InputEventKey).physical_keycode
		== KEY_ALT
	)
	level.free()
	ECS.world = null
	print("R02 interaction smoke PASS")
	get_tree().quit()
