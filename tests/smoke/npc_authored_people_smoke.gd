extends Node
## Два отдельных процесса: сохранение авторского пилота и cold-load с другим creation seed.

const PILOT_PATH: String = (
	"res://content/domains/npc/definitions/def_district_authored_pilot.tres"
)
const SAVE_PATH: String = "user://npc_authored_people_smoke.pvzh"
const WRITE_SEED: int = 11
const RESTORE_CREATION_SEED: int = 999
const EXPECTED_HEALTH: float = 41.0
const ENTITY_SCRIPT: Script = preload("res://addons/gecs/ecs/entity.gd")


## Пустой startup slot отделяет fixture от сохранения обычной кампании.
class FixtureLevel extends Node3D:
	## Gameplay-пути пользователя здесь не читаются.
	var autosave_path: String = ""


var _failed: bool = false
var _root: Node3D
var _world: World


#region Real process boundary
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	if not restoring:
		_cleanup_slot()
	_create_world(RESTORE_CREATION_SEED if restoring else WRITE_SEED)
	if not _failed:
		if restoring:
			_restore()
		else:
			_write()
	_dispose_world()
	if restoring:
		_cleanup_slot()
	print(
		_completion_prefix(),
		" ",
		"restore" if restoring else "write",
		": ",
		"FAIL" if _failed else "PASS",
	)
	get_tree().quit(1 if _failed else 0)


func _create_world(world_seed: int) -> void:
	_root = FixtureLevel.new()
	add_child(_root)
	var marker: Node3D = Node3D.new()
	marker.name = "District"
	_root.add_child(marker)
	_world = _make_world()
	_root.add_child(_world)
	ECS.world = _world
	DialogueUiFixture.install()
	NpcCustomerComposition.install(_world)
	_world.add_observer(O_WalletDay.new())
	_world.add_observer(O_DistrictLifecycle.new())
	_world.add_observer(O_CustomerPlanning.new())
	var session_node: Node = Node.new()
	session_node.set_script(ENTITY_SCRIPT)
	var session: Entity = session_node as Entity
	var district_recipe: C_District = C_District.new()
	district_recipe.definition = load(_pilot_path())
	var calendar_recipe: C_DayCycle = C_DayCycle.new()
	calendar_recipe.clock.world_seed = world_seed
	session.component_resources = [district_recipe, calendar_recipe]
	_world.add_entity(session)
	_check(DistrictPopulationService.initialize(), "native pilot construction")
	if _world is GameWorld:
		var production_world: GameWorld = _world as GameWorld
		production_world.finish_startup()
		_check(production_world.composition_ready(), "complete GameWorld startup")
		_check(DistrictPopulationService.prepare_morning(1).succeeded, "prepared first Morning")
	_check(
		NpcPopulationQueries.current().people.size()
		== district_recipe.definition.authored_people.size(),
		"complete authored roster",
	)
	_check(GameTimeQueries.current().world_seed == world_seed, "requested creation seed")


func _write() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	(body.get_component(C_Health) as C_Health).current = EXPECTED_HEALTH
	NpcDialogueMemoryService.set_tag(person, &"visited")
	NpcDialogueMemoryService.set_val(person, &"quest_stage", 2)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	_check(WorldSnapshotService.can_restore(snapshot, _root), "complete authored snapshot")
	if _failed:
		return
	_check(AutosaveStore.write(snapshot, _save_path()) == OK, "isolated disk write")


func _restore() -> void:
	var before: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	_check(before.dialogue_tags.is_empty(), "new process has no inherited author memory")
	var snapshot: Dictionary = AutosaveStore.read(_save_path())
	_check(not snapshot.is_empty(), "cold native disk read")
	_check(WorldSnapshotService.restore(snapshot, _root), "cold authored restore")
	if _failed:
		return
	var district: C_District = NpcPopulationQueries.current()
	_check(district.next_person == 10, "sparse IDs remain reserved")
	_check(GameTimeQueries.current().world_seed == WRITE_SEED, "saved clock replaces new seed")
	for person: NpcRecord in district.people:
		var card: DEF_NpcPerson = district.definition.person_for(person.npc_id)
		_check(
			NpcAuthoredPersonRules.matches(card, person),
			"fixed identity " + String(person.npc_id),
		)
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		_check(body.scene_file_path == card.npc_scene_path, "authored native body scene")
	var restored: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	_check(restored.dialogue_tags.get(&"visited", false), "persistent dialogue flag")
	_check(restored.dialogue_values.get(&"quest_stage") == 2, "persistent author quest value")
	var restored_body: E_DistrictNpc = NpcPopulationQueries.body_for(restored.npc_id)
	_check(
		(restored_body.get_component(C_Health) as C_Health).current == EXPECTED_HEALTH,
		"physical health remains owned by body",
	)


func _dispose_world() -> void:
	for actor: Entity in _world.entities.duplicate():
		if is_instance_valid(actor):
			_world.remove_entity(actor)
	_world.purge(false)
	ECS.world = null
	_root.free()


func _cleanup_slot() -> void:
	var path: String = _save_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _make_world() -> World:
	return World.new()


func _pilot_path() -> String:
	return PILOT_PATH


func _save_path() -> String:
	return SAVE_PATH


func _completion_prefix() -> String:
	return "Authored people smoke"


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(_completion_prefix() + ": " + message)
#endregion
