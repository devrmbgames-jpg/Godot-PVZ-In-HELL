extends Node
## Headless-приёмка соседей: пять минут каждой фазы, сохранность исходного населения и реальные выходы через навигацию.

## Продолжительность одной фазы в игровых секундах, включая время на длинные пути района.
const PHASE_SECONDS: int = 300
## Минимум исходных местных жителей после каждой фазы пассивного игрока.
const MINIMUM_RESIDENT_SURVIVORS: int = 6

var _level: Node3D = null
var _failed: bool = false

#region Связный прогон основной сцены
func _ready() -> void:
	_run.call_deferred()

## Использует отдельный мир без загрузки autosave; физика и реальные фазы продолжают работать штатно.
func _run() -> void:
	Engine.max_fps = 0
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	_level.set("autosave_path", "")
	add_child(_level)
	var district: C_District = DistrictPopulationService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	var initial_residents: Array[StringName] = []
	for person: NpcRecord in district.people:
		if person.profile.resident:
			initial_residents.append(person.npc_id)
	_check(initial_residents.size() == district.definition.resident_count, "initial resident population")
	var verified_exits: int = 0
	for phase: C_DayCycle.Phase in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		var departing: Array[StringName] = []
		for person: NpcRecord in district.people:
			var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(cycle.day_index, phase)
			var leaves_street: bool = person.placement == NpcRecord.Placement.STREET and location == DEF_NpcSchedule.Location.OUTSIDE
			var passes_through: bool = not person.profile.resident and location == DEF_NpcSchedule.Location.STREET
			if person.death_day == 0 and (leaves_street or passes_through):
				departing.append(person.npc_id)
		cycle.phase = phase
		print("Neighbour smoke phase=", phase, " departing=", departing)
		for frame: int in PHASE_SECONDS * Engine.physics_ticks_per_second:
			await get_tree().physics_frame
			if frame % (60 * Engine.physics_ticks_per_second) == 0:
				print("Neighbour minute phase=", phase, " elapsed=", frame / Engine.physics_ticks_per_second, " survivors=", _survivors(initial_residents))
		var survivors: int = _survivors(initial_residents)
		_check(survivors >= MINIMUM_RESIDENT_SURVIVORS, "original residents survive phase %d: %d" % [phase, survivors])
		_check(district.ambient_conflicts <= district.definition.ambient_conflicts_per_phase, "ambient conflict budget")
		for npc_id: StringName in departing:
			var person: NpcRecord = DistrictPopulationService.person_for(npc_id)
			var body: E_DistrictNpc = DistrictPopulationService.body_for(npc_id)
			if person.placement == NpcRecord.Placement.STREET:
				var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
				print("Unfinished exit ", npc_id, " position=", body.global_position, " goal=", person.goal_id, " complete=", person.phase_complete, " behavior=", decision.active_behavior)
			_check(person.death_day == 0, "departing NPC remains alive: " + str(npc_id))
			_check(person.placement == NpcRecord.Placement.OUTSIDE, "NPC actually leaves district: " + str(npc_id))
			_check(not body.enabled and not body.visible and body.collision_layer == 0, "outside body does not participate: " + str(npc_id))
			_check(not body.navigation_agent.avoidance_enabled, "outside body leaves navigation avoidance: " + str(npc_id))
			_check(CombatService.target_for(body) == null and not (body.get_component(C_NpcIntent) as C_NpcIntent).movement_active, "exit clears actions: " + str(npc_id))
			if person.placement == NpcRecord.Placement.OUTSIDE:
				verified_exits += 1
		print("Neighbour phase complete=", phase, " survivors=", survivors, " verified_exits=", verified_exits)
	_check(verified_exits > 0, "at least one physical schedule exit verified")
	_level.free()
	ECS.world = null
	for frame: int in 6:
		await get_tree().process_frame
	print("NPC neighbour safety smoke ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)
#endregion

#region Наблюдение результата
func _survivors(identities: Array[StringName]) -> int:
	var survivors: int = 0
	for npc_id: StringName in identities:
		if DistrictPopulationService.person_for(npc_id).death_day == 0:
			survivors += 1
	return survivors

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("NPC neighbour safety: " + message)
#endregion
