extends Node
## Real main scene: collider ancestry, contextual prompts and physical completion.

const FRAME_DELTA: float = 1.0 / 60.0
const SETTLE_FRAMES: int = 360
const ENDPOINT_TOLERANCE: float = 0.02

var _level: Node = null
var _actor: Entity = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = scene.instantiate()
	add_child(_level)
	_level.set_physics_process(false)
	_actor = _level.get_node("Entityes/Player") as Entity
	(_actor as Node as RigidBody3D).freeze = true
	(_actor as Node as Node3D).global_position = Vector3(7, 0, -2)

	var offsets: Array[Vector3] = [Vector3(0.8, 1.4, 0), Vector3(1, 1, 0), Vector3.ZERO]
	var names: Array[String] = ["DoorTemplate", "Window", "Drawer"]
	for index: int in names.size():
		var target: E_Openable = _level.get_node("Entityes/" + names[index]) as E_Openable
		await _aim(target, offsets[index])
		var state: C_Openable = target.get_component(C_Openable) as C_Openable
		var action: InteractionActionChoice = InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.INTERACT)
		assert(action != null and action.source == target, "Physical collider must route to its owner Entity")
		assert(action.action.caption == "Открыть")
		InteractionActionResolver.refresh_prompt(_actor)
		assert((_actor.get_component(C_Interactor) as C_Interactor).prompt_text.contains("Открыть"))
		action.action.execute(_actor, action.source, action.target)
		assert(state.requested_open)
		action = InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.INTERACT)
		assert(action != null and action.action.caption == "Закрыть")
		await _frames(SETTLE_FRAMES)
		assert(state.actual_fraction >= 1.0 - ENDPOINT_TOLERANCE, "Main scene geometry must permit opening")
		action.action.execute(_actor, action.source, action.target)
		await _frames(SETTLE_FRAMES)
		assert(state.actual_fraction <= ENDPOINT_TOLERANCE)

	var light_switch: Entity = _level.get_node("Entityes/LightSwitch") as Entity
	await _aim(light_switch, Vector3.ZERO, Vector3.RIGHT)
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.INTERACT)
	assert(choice != null and choice.source == light_switch)
	choice.action.execute(_actor, choice.source, choice.target)
	assert(not LightCircuitService.is_enabled(&"warehouse"))
	var lights: Array[Node] = get_tree().get_nodes_in_group(&"warehouse_lights")
	assert(lights.size() == 3)
	for node: Node in lights:
		assert(not (node as Light3D).visible)
	assert((_level.get_node("WorldEnvironment/DirectionalLight3D") as Light3D).visible)
	(light_switch.get_component(C_Interactable) as C_Interactable).enabled = false
	InteractionActionResolver.refresh_prompt(_actor)
	assert(not (_actor.get_component(C_Interactor) as C_Interactor).prompt_text.contains("Переключить"))
	_level.free()
	ECS.world = null
	print("Environment main-scene targeting prompts physical endpoints and light groups smoke PASS")
	get_tree().quit.call_deferred()


func _aim(target: Entity, offset: Vector3, approach: Vector3 = Vector3.BACK) -> void:
	var position: Vector3 = (target as Node as Node3D).global_position + offset
	var ray: RayCast3D = GrabService.interaction_raycast(_actor)
	ray.global_position = position + approach * 1.5
	ray.look_at(position)
	await _frames(2)
	var interactor: C_Interactor = _actor.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingService.find_target(_actor, interactor)
	assert(interactor.target == target, "Targeting must hit the actual main-scene interaction surface")


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame
