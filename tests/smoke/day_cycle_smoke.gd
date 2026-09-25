extends Node

var _level: Node = null
var _actor: Entity = null
var _controller: C_Controller = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = scene.instantiate()
	add_child(_level)
	_level.set_physics_process(false)
	_actor = _level.get_node("Entityes/Player") as Entity
	_controller = _actor.get_component(C_Controller) as C_Controller
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cycle: C_DayCycle = DayPhaseService.current()
	assert(cycle != null and cycle.phase == C_DayCycle.Phase.MORNING)
	assert(not DayPhaseService.permits(cycle, DayTransitionRequest.Kind.SLEEP))
	var stale: DayTransitionRequest = DayTransitionRequest.new()
	stale.expected_day = cycle.day_index
	stale.expected_phase = cycle.phase
	for tick_index: int in 10:
		ECS.world.process(100.0, "GamePlay")
	assert(cycle.phase == C_DayCycle.Phase.MORNING)
	_use_station("ShiftConsole")
	assert(cycle.phase == C_DayCycle.Phase.DAY)
	assert(not DayPhaseService.submit(stale))
	cycle.remaining_customer_events = 1
	_use_station("ShiftConsole")
	assert(cycle.phase == C_DayCycle.Phase.DAY)
	cycle.remaining_customer_events = 0
	_use_station("ShiftConsole")
	assert(cycle.phase == C_DayCycle.Phase.EVENING)
	_use_station("SleepPoint")
	assert(cycle.phase == C_DayCycle.Phase.NIGHT and cycle.day_index == 1)
	cycle.night_ready = false
	ECS.world.process(1.0, "GamePlay")
	assert(cycle.phase == C_DayCycle.Phase.NIGHT and cycle.day_index == 1)
	cycle.night_ready = true
	ECS.world.process(1.0, "GamePlay")
	assert(cycle.phase == C_DayCycle.Phase.MORNING and cycle.day_index == 2)
	assert(not DayPhaseService.submit(stale))
	ECS.world.process(1.0, "GamePlay")
	assert(cycle.day_index == 2)
	_level.free()
	ECS.world = null
	print("R03 world-action day cycle smoke PASS")
	get_tree().quit()


func _use_station(station_name: String) -> void:
	var station: Node3D = _level.get_node("Entityes/" + station_name) as Node3D
	var ray: RayCast3D = GrabService.interaction_raycast(_actor)
	ray.look_at(station.global_position + Vector3.UP * 0.55)
	_controller.interact_pressed = true
	_controller.input_tick += 1
	ECS.world.process(1.0 / 60.0, "Interaction")
	ECS.world.process(1.0 / 60.0, "GamePlay")
