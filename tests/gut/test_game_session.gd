extends GutTest
## Минимальный реальный World: сохранение из modal меню, запреты и preflight без мутации.

const SAVE_PATH: String = "user://r34_service_test.pvzh"
const SETTINGS_PATH: String = "user://r34_settings_test.cfg"
var _root: Node
var _world: World
var _actor: Entity
var _session: Entity
var _cycle: C_DayCycle


func before_each() -> void:
	_root = Node.new()
	_root.scene_file_path = GameSessionService.MAIN_LEVEL
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	_session = _authored("Session", [C_DayCycle.new()])
	_cycle = _session.get_component(C_DayCycle) as C_DayCycle
	_actor = _authored("Actor", [C_Inventory.new(), C_GrabControl.new(), C_Health.new()])


func _authored(label: String, components: Array[Component]) -> Entity:
	var entity: Entity = Entity.new()
	entity.name = label
	entity.component_resources = components
	_root.add_child(entity)
	entity.owner = _root
	_world.add_entity(entity, null, false)
	return entity


func after_each() -> void:
	get_tree().paused = false
	_world.purge(false)
	_root.free()
	ECS.world = null
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp", SETTINGS_PATH]:
		DirAccess.remove_absolute(path)


func test_own_pause_token_allows_save_and_real_slot_round_trip() -> void:
	var token: int = InteractionControlFocus.acquire(_actor, self, InteractionControlFocus.Priority.MODAL)
	assert_eq(GameSessionService.save_reason(_root, self), "")
	assert_false(GameSessionService.save_reason(_root).is_empty(), "Другой modal не игнорируется")
	var result: GameSaveResult = GameSessionService.save_game(_root, self, SAVE_PATH)
	assert_true(result.success, result.message)
	var data: Dictionary = AutosaveStore.read(SAVE_PATH)
	assert_eq(String(data.level_scene), GameSessionService.MAIN_LEVEL)
	assert_true(WorldSnapshotService.can_restore(data, _root))
	assert_eq(_cycle.phase, C_DayCycle.Phase.MORNING)
	InteractionControlFocus.release(_actor, token)


func test_day_and_capture_refuse_save_without_overwriting_slot() -> void:
	assert_true(GameSessionService.save_game(_root, null, SAVE_PATH).success)
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(SAVE_PATH)
	_cycle.phase = C_DayCycle.Phase.DAY
	assert_false(GameSessionService.save_game(_root, null, SAVE_PATH).success)
	assert_eq(FileAccess.get_file_as_bytes(SAVE_PATH), saved)
	_cycle.phase = C_DayCycle.Phase.MORNING
	var token: int = InteractionControlFocus.acquire(_actor, self, InteractionControlFocus.Priority.CARRY)
	assert_false(GameSessionService.save_reason(_root).is_empty())
	assert_false(GameSessionService.save_game(_root, null, SAVE_PATH).success)
	assert_eq(FileAccess.get_file_as_bytes(SAVE_PATH), saved)
	InteractionControlFocus.release(_actor, token)


func test_customer_or_held_relationship_blocks_even_with_menu_token() -> void:
	var npc: Entity = Entity.new()
	npc.component_resources = [C_CustomerAgent.new()]
	_world.add_entity(npc)
	assert_false(GameSessionService.save_reason(_root, self).is_empty())
	_world.remove_entity(npc)
	var item: Entity = Entity.new()
	_world.add_entity(item)
	item.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	assert_false(GameSessionService.save_reason(_root, self).is_empty())
	_world.remove_entity(item)


func test_preflight_rejects_bad_prefab_roles_without_live_world_changes() -> void:
	var data: Dictionary = WorldSnapshotService.capture(_root, 1)
	var size_before: int = _world.entities.size()
	assert_true(WorldSnapshotService.can_restore(data, _root))
	assert_eq(_world.entities.size(), size_before)
	for record: Dictionary in data.entities:
		if String(record.authored_path) == "Actor":
			record.anchor = {"freeze": false, "freeze_mode": 0, "can_sleep": true}
	assert_false(WorldSnapshotService.can_restore(data, _root), "Entity без native anchor нельзя загрузить")
	assert_eq(_world.entities.size(), size_before)
	assert_eq(_cycle.phase, C_DayCycle.Phase.MORNING)


func test_profile_paths_separate_main_and_primitive() -> void:
	assert_ne(GameSessionService.manual_path(GameSessionService.MAIN_LEVEL), GameSessionService.manual_path(GameSessionService.TEST_LEVEL))
	assert_eq(GameSessionService.autosave_path(GameSessionService.MAIN_LEVEL), AutosaveStore.DEFAULT_PATH)
	assert_eq(GameSessionService.autosave_path(GameSessionService.TEST_LEVEL), "user://primitive_test_level.pvzh")
	assert_false(GameSessionService.saved_game("res://content/ui/main_menu.tscn").success)


func test_main_settings_without_actor_pause_release_and_no_fake_capture() -> void:
	var menu: SettingsMenu = SettingsMenu.new()
	menu.setup_main_menu(SETTINGS_PATH)
	_root.add_child(menu)
	assert_true(menu.open_menu())
	assert_true(get_tree().paused)
	assert_true(menu.is_open())
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)
	menu.close_menu()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)
	assert_true(FileAccess.file_exists(SETTINGS_PATH))
