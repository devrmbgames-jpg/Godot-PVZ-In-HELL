extends Node
## Reproducible headless CPU benchmark on the authored level, without changing its geometry.

const SAMPLE_COUNT: int = 12
const LIGHT_SAMPLES: int = 809
const FRAME_COUNT: int = 240

var _level: Node3D = null

#region Measurement
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = scene.instantiate() as Node3D
	_level.set("autosave_path", "")
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	for frame: int in 30:
		await get_tree().physics_frame
	_level.set_physics_process(false)

	var district: C_District = DistrictPopulationService.current()
	var lighting: NpcLightingContext = NpcLightingService.context_for(district)
	print("NPC benchmark authored_light_zones=", lighting.zones.size(), " shade_points=", district.definition.shade_route.size())
	if lighting.zones.is_empty():
		push_error("NPC benchmark requires the authored light volumes")
		get_tree().quit(1)
		return
	var person: NpcRecord = null
	for candidate: NpcRecord in district.people:
		if candidate.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION) != null:
			person = candidate
			break
	var actor: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var map: RID = actor.navigation_agent.get_navigation_map()
	var start: Vector3 = DistrictPopulationService.position_for(person.portal_id)
	var goal: Vector3 = DistrictPopulationService.position_for(&"shop")
	var measurements: PackedFloat64Array = PackedFloat64Array()
	for sample: int in SAMPLE_COUNT:
		var began: int = Time.get_ticks_usec()
		var path: PackedVector3Array = NpcRouteService.plan(actor, person, start, goal, map)
		measurements.append(float(Time.get_ticks_usec() - began) / 1000.0)
		if path.is_empty():
			push_error("NPC benchmark route is empty")
			get_tree().quit(1)
			return
	_report("route_ms", measurements)

	measurements.clear()
	for sample: int in SAMPLE_COUNT:
		var began: int = Time.get_ticks_usec()
		for index: int in LIGHT_SAMPLES:
			var fraction: float = float(index % 37) / 36.0
			NpcLightingService.exposure_at(start.lerp(goal, fraction) + Vector3.UP, [actor.get_rid()])
		measurements.append(float(Time.get_ticks_usec() - began) / 1000.0)
	_report("809_light_queries_ms", measurements)

	var cycle: C_DayCycle = DayPhaseService.current()
	for phase: C_DayCycle.Phase in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		cycle.phase = phase
		measurements.clear()
		for frame: int in FRAME_COUNT:
			await get_tree().physics_frame
			var began: int = Time.get_ticks_usec()
			_level.call("_physics_process", 1.0 / 60.0)
			measurements.append(float(Time.get_ticks_usec() - began) / 1000.0)
		_report("scheduled_work_phase_%d_ms" % phase, measurements)

	_level.free()
	ECS.world = null
	print("NPC benchmark PASS")
	get_tree().quit()

func _report(label: String, values: PackedFloat64Array) -> void:
	values.sort()
	print("NPC benchmark ", label, ": median=", snappedf(values[values.size() / 2], 0.001),
		" p95=", snappedf(values[mini(values.size() - 1, int(values.size() * 0.95))], 0.001),
		" max=", snappedf(values[values.size() - 1], 0.001), " samples=", values.size())
#endregion
