extends Node
## Temporary validation for the authored R11.1 valve fixtures.

var _world: World


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main_scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	assert(main_scene != null)

	var packed: PackedScene = load("res://content/entities/props/interaction_test_valve.tscn") as PackedScene
	assert(packed != null)

	_world = World.new()
	add_child(_world)
	ECS.world = _world

	var expected_slots: Array[int] = [0, 1, 1, 1, 1]
	var expected_policies: Array[int] = [-1, 0, 1, 2, 3]

	for mode_index: int in 5:
		var valve: E_InteractionTestValve = packed.instantiate() as E_InteractionTestValve
		assert(valve != null)
		valve.mode = mode_index
		_world.add_entity(valve)
		await get_tree().process_frame

		var actions: C_InteractionActionSet = valve.get_component(C_InteractionActionSet) as C_InteractionActionSet
		assert(actions != null)

		var available: Array[DEF_InteractionAction] = []
		for action: DEF_InteractionAction in actions.actions:
			if action != null and action.is_available(null, valve, valve):
				available.append(action)

		assert(available.size() == 1)
		var selected: DEF_InteractionAction = available[0]
		assert(selected.slot == expected_slots[mode_index])
		if expected_policies[mode_index] < 0:
			assert(selected.timing == null)
		else:
			assert(selected.timing != null)
			assert(selected.timing.reset_policy == expected_policies[mode_index])

		var lamp: Node3D = valve.get_node("IndicatorLamp") as Node3D
		var on_bulb: MeshInstance3D = lamp.get_node("OnBulb") as MeshInstance3D
		assert(not on_bulb.visible)
		valve.activate()
		await get_tree().process_frame
		assert(on_bulb.visible)

		valve.queue_free()
		await get_tree().process_frame

	_world.free()
	ECS.world = null
	print("R11.1 valve fixture smoke PASS")
	get_tree().quit()
