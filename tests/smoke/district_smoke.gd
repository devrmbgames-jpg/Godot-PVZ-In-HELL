extends Node
## Connected headless district week with real phase systems, native navigation and save restoration.

const SAVE_PATH: String = "user://smoke_living_district.pvzh"
const PHASE_FRAMES: int = 720
const NAVIGATION_CHECKS: GDScript = preload("res://utils/warehouse_navigation_checks.gd")

var _level: Node3D = null
var _failed: bool = false

#region Week runner
func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = packed.instantiate() as Node3D
	_level.set("autosave_path", "")
	get_tree().root.add_child(_level)
	get_tree().current_scene = _level
	print("District smoke: level initialized")
	var navigation_region: NavigationRegion3D = _level.get_node("WarehouseNavigation") as NavigationRegion3D
	var navigation_errors: Array[String] = await NAVIGATION_CHECKS.failures(_level, navigation_region)
	for navigation_error: String in navigation_errors:
		_check(false, navigation_error)
	if not navigation_errors.is_empty():
		_level.free()
		ECS.world = null
		get_tree().quit(1)
		return

	var cycle: C_DayCycle = DayPhaseService.current()
	var district: C_District = DistrictPopulationService.current()
	var session: Entity = ECS.world.query.with_all([C_Autosave]).execute_one()
	var autosave: C_Autosave = session.get_component(C_Autosave) as C_Autosave
	autosave.path = SAVE_PATH
	var initial: Array[StringName] = []
	for person: NpcRecord in district.people:
		if person.profile.resident:
			initial.append(person.npc_id)
	_check(district.people.size() == 12, "initial 8+4 population")
	var returning: StringName = district.people[8].npc_id
	var returning_body: E_DistrictNpc = DistrictPopulationService.body_for(returning)
	for day_index: int in range(1, 8):
		for phase: C_DayCycle.Phase in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
			print("District smoke phase ",day_index,"/",phase)
			cycle.phase = phase
			for frame: int in PHASE_FRAMES:
				await get_tree().physics_frame
		cycle.phase = C_DayCycle.Phase.NIGHT
		cycle.night_ready = false
		for frame: int in 120:
			await get_tree().physics_frame
			if cycle.phase == C_DayCycle.Phase.MORNING:
				break
		_check(cycle.day_index == day_index + 1, "night advances exactly once on day %d" % day_index)
		_check(autosave.last_error == OK, "night snapshot is valid on day %d" % day_index)
		print("District smoke morning ", cycle.day_index, ": records=", district.people.size(), " bodies=", ECS.world.query.with_all([C_NpcIdentity]).execute().size())
	var survivors: int = 0
	for identity: StringName in initial:
		if DistrictPopulationService.person_for(identity).death_day == 0:
			survivors += 1
	_check(survivors >= 6, "passive original residents survive: %d" % survivors)
	_check(DistrictPopulationService.body_for(returning) == returning_body, "weekly visitor uses the same body")
	var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
	_check(WorldSnapshotService.can_restore(snapshot, _level), "saved week is restorable")
	_check(WorldSnapshotService.restore(snapshot, _level), "week restoration succeeds")
	_check(DistrictPopulationService.current().people.size() == district.people.size(), "restoration does not duplicate population")
	_level.free()
	ECS.world = null
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("District smoke ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		push_error("District smoke: " + label)
#endregion
