extends Node
## Two actual processes prove scheduled Night preparation and passive startup restore of the main level.

const SAVE_PATH: String = "user://night_persistence_smoke.pvzh"
const MAX_FRAMES: int = 600
const DELTA: float = 1.0 / 60.0
const EXPECTED_BALANCE: int = -275
const EXPECTED_HUNGER: float = 55.0

var _failed: bool = false

#region Scheduled save and process restart
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	if not restoring:
		_cleanup()
	var level: Node3D = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	level.set("autosave_path", SAVE_PATH)
	if restoring:
		var box: Node = level.get_node("Entityes/AnchorableTestBox")
		box.name = "RenamedPersistentBox"
	add_child(level)
	level.set_physics_process(false)
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	(actor as Node as CharacterBody3D).set_physics_process(false)
	if restoring:
		_verify_restored(level, actor)
	else:
		await _write_night(level, actor)
	level.free()
	if restoring:
		_cleanup()
	print("Night persistence smoke ", "restore" if restoring else "write", ": ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)


func _write_night(level: Node3D, actor: Entity) -> void:
	WalletService.current().balance = EXPECTED_BALANCE
	(actor.get_component(C_Hunger) as C_Hunger).value = EXPECTED_HUNGER
	var med: Entity = level.get_node("Entityes/MedPickup") as Entity
	_check(InventoryService.transfer(med, actor), "real inventory pickup accepted")
	var box: Entity = level.get_node("Entityes/AnchorableTestBox") as Entity
	var slot: Entity = level.get_node("Entityes/Player/BeltSlotLeft") as Entity
	var stored: Relationship = Relationship.new(R_StoredIn.new(), slot)
	box.add_relationship(stored)
	_check(PhysicalSlotService.attach(box, stored), "real physical slot attached")
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.NIGHT
	cycle.night_ready = false
	for _frame: int in MAX_FRAMES:
		ECS.world.process(DELTA, "GamePlay")
		if cycle.day_index == 2:
			break
		await get_tree().physics_frame
	_check(cycle.day_index == 2 and cycle.phase == C_DayCycle.Phase.MORNING, "actual Night owner completed prepared Morning")
	var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
	_check(not snapshot.is_empty() and snapshot.get("morning_day") == 2, "real atomic slot contains Morning 2")
	_check(WorldSnapshotService.can_restore(snapshot, level), "saved prefab/recipe/link graph validates")


func _verify_restored(level: Node3D, actor: Entity) -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	_check(cycle.day_index == 2 and cycle.phase == C_DayCycle.Phase.MORNING, "new process restored Morning 2")
	_check(WalletService.current().balance == EXPECTED_BALANCE, "saved debt was not reset by startup")
	_check(is_equal_approx((actor.get_component(C_Hunger) as C_Hunger).value, EXPECTED_HUNGER), "saved hunger overlay applied")
	_check(InventoryService.items(actor).size() == 1, "one restored inventory item")
	var box: Entity = level.get_node("Entityes/RenamedPersistentBox") as Entity
	var slot: Entity = level.get_node("Entityes/Player/BeltSlotLeft") as Entity
	var links: Array[Relationship] = box.get_relationships(Relationship.new(R_StoredIn.new()))
	_check(links.size() == 1 and links[0].target == slot, "renamed authored body retains physical link by explicit ID")
	_check(NpcPopulationQueries.current().prepared_morning == 2, "prepared district restored without preparing another Morning")
	_check(MetaPresentation.debug_text().contains("Восстановлено утро 2"), "startup published restored readiness")
#endregion

#region Deterministic smoke reporting
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var filename: String = ProjectSettings.globalize_path(SAVE_PATH + suffix)
		if FileAccess.file_exists(filename):
			DirAccess.remove_absolute(filename)
#endregion
