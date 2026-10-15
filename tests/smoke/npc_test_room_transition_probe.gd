extends Node
## Headless native scene replacement through actual portal actions, including fresh re-entry.

const SETTLE_FRAMES: int = 120
const MAX_TRANSITION_FRAMES: int = 120
const MAX_SUPPLY_FRAMES: int = 600

var _failed: bool = false
var _checks: int = 0
var _completed_rooms: int = 0
var _entries: int = 0


#region Native driver
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Keep only this driver outside replaced scenes; actual gameplay roots are freed.
	get_tree().current_scene = null
	var opened: Error = GameSessionService.start_game(get_tree(), GameSessionService.TEST_LEVEL)
	_check(opened == OK, "Open hall")
	if _failed or not await _arrive(GameSessionService.TEST_LEVEL):
		get_tree().quit(1)
		return
	var hall: Node = get_tree().current_scene
	var hall_count: int = get_tree().get_node_count()
	_check(_catalog_present(hall), "All sixteen physical catalog scenes and ten portals")

	for key: StringName in GameSessionService.TEST_ROOM_KEYS:
		if _failed:
			break
		await _roundtrip(key, hall_count)

	_check(
		_completed_rooms == GameSessionService.TEST_ROOM_KEYS.size(),
		"Every canonical room completed both entries and returns",
	)
	_check(_entries == _completed_rooms * 2, "Two actual fresh entries per completed room")
	if not _failed:
		print(
			"NPC test-room transition probe: PASS checks=",
			_checks,
			" rooms=",
			_completed_rooms,
			" entries=",
			_entries,
		)
	get_tree().quit(1 if _failed else 0)


func _roundtrip(key: StringName, hall_count: int) -> void:
	var portal_path: String = "Entityes/NpcRoomPortals/Portal_" + String(key)
	var room_path: String = GameSessionService.test_room_path(key)
	var old_hall: WeakRef = weakref(get_tree().current_scene)
	var old_hall_world: WeakRef = weakref(ECS.world)
	if not await _transition(portal_path, room_path):
		return
	_entries += 1
	_check(old_hall.get_ref() == null, String(key) + ": old hall freed")
	_check(old_hall_world.get_ref() == null, String(key) + ": old World freed")
	if not _room_state(key):
		return
	await _physical_supply(key)
	if _failed:
		return

	var room_count: int = get_tree().get_node_count()
	var old_room: WeakRef = weakref(get_tree().current_scene)
	var old_world: WeakRef = weakref(ECS.world)
	var person: NpcRecord = NpcPopulationQueries.current().people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var old_actor: WeakRef = weakref(body)
	get_tree().current_scene.set_physics_process(false)
	# A live cross-Entity binding must disappear with its owning scene.
	NpcIntentService.follow(body, _player(), 0.5)
	_check(body.relationships.size() > 0, String(key) + ": live movement binding installed")
	person.memories.append(NpcMemory.new())
	DayPhaseQueries.current().day_index = 9
	if not await _transition("Entityes/ReturnPortal", GameSessionService.TEST_LEVEL):
		return
	_check(old_room.get_ref() == null, String(key) + ": room freed")
	_check(old_world.get_ref() == null, String(key) + ": room World freed")
	_check(old_actor.get_ref() == null, String(key) + ": bound NPC freed")
	_check(get_tree().get_node_count() == hall_count, String(key) + ": no accumulating hall Nodes")
	if _failed or not await _transition(portal_path, room_path):
		return
	_entries += 1
	if not _room_state(key):
		return
	await _physical_supply(key)
	if _failed:
		return
	_check(DayPhaseQueries.current().day_index == 1, String(key) + ": calendar resets")
	var fresh_person: NpcRecord = NpcPopulationQueries.current().people[0]
	_check(fresh_person.memories.is_empty(), String(key) + ": memory resets")
	var fresh: E_DistrictNpc = NpcPopulationQueries.body_for(fresh_person.npc_id)
	for binding: Relationship in fresh.relationships:
		_check(not binding.relation is R_NpcMoveTarget, String(key) + ": no stale player target")
	_check(get_tree().get_node_count() == room_count, String(key) + ": no accumulating room Nodes")
	if _failed or not await _transition("Entityes/ReturnPortal", GameSessionService.TEST_LEVEL):
		return
	_check(
		get_tree().get_node_count() == hall_count,
		String(key) + ": second return has stable Nodes",
	)
	if not _failed:
		_completed_rooms += 1
		print("NPC room native transition/reset: ", key, " PASS")


func _arrive(expected: String) -> bool:
	# Scene replacement is asynchronous; timeout/bootstrap failure must never become exit-zero PASS.
	var arrived: bool = false
	for frame: int in MAX_TRANSITION_FRAMES:
		var root: Node = get_tree().current_scene
		if root != null and root.scene_file_path == expected:
			arrived = true
			break
		await get_tree().process_frame
	_check(arrived, "Bounded native scene arrival: " + expected)
	if not arrived:
		return false
	await _settle(SETTLE_FRAMES)
	var root: Node = get_tree().current_scene
	var world: GameWorld = ECS.world as GameWorld
	var initialized: bool = (
		root != null and root.scene_file_path == expected and world != null
		and world.get_parent() == root and not world.initialization_failed()
	)
	_check(initialized, "Live initialized World after scene replacement: " + expected)
	return initialized and not _failed


func _transition(path: String, expected: String) -> bool:
	if _failed or not _portal(path):
		return false
	return await _arrive(expected)


func _settle(frames: int) -> void:
	for frame: int in frames:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("NPC test-room transition probe: " + message)
#endregion


#region Native portal and physical session assertions
func _player() -> Entity:
	return ECS.world.query.with_all([C_PlayerInputController]).execute_one()


func _portal(path: String) -> bool:
	var portal: Entity = get_tree().current_scene.get_node_or_null(path) as Entity
	_check(portal != null, "Authored portal exists: " + path)
	if portal == null:
		return false
	var actions: C_InteractionActionSet = (
		portal.get_component(C_InteractionActionSet) as C_InteractionActionSet
	)
	var action: DEF_TestRoomAction = actions.actions[0] as DEF_TestRoomAction
	var accepted: bool = action.complete(_player(), portal, portal)
	_check(accepted, "Native contextual transition accepted: " + path)
	return accepted


func _room_state(key: StringName) -> bool:
	var world: GameWorld = ECS.world as GameWorld
	var district: C_District = NpcPopulationQueries.current()
	_check(district != null and district.people.size() == 1, String(key) + ": one person")
	_check(world.query.with_all([C_NpcIdentity]).execute().size() == 1, String(key)
		+ ": one NPC body")
	if _failed:
		return false
	var preset: DEF_NpcTestRoom = get_tree().current_scene.get_meta("npc_test_room")
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(district.people[0].npc_id)
	_check(
		body.enabled and body.is_visible_in_tree()
		and district.people[0].placement == NpcRecord.Placement.STREET,
		String(key) + ": NPC physically present and visible after native transition",
	)
	_check(preset.room_key == key, String(key) + ": canonical room preset")
	_check(
		district.people[0].profile.key == preset.district.profiles[0].key,
		String(key) + ": canonical archetype",
	)
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	_check(flow.schedule.supply.maximum_batch_packages == 2, String(key) + ": two daily parcels")
	_check(flow.schedule.events.size() == 2, String(key) + ": two native service cases")
	_check(
		get_tree().current_scene.get("autosave_path") == "",
		String(key) + ": no gameplay save slot",
	)
	_check(DayPhaseQueries.current().day_index == 1, String(key) + ": fresh calendar")
	return not _failed


func _physical_supply(key: StringName) -> void:
	for frame: int in MAX_SUPPLY_FRAMES:
		var parcels: Array[Entity] = ECS.world.query.with_all([C_Package]).execute()
		if parcels.size() >= 2:
			break
		await get_tree().physics_frame
	var parcels: Array[Entity] = ECS.world.query.with_all([C_Package]).execute()
	_check(parcels.size() == 2, String(key) + ": exactly two native physical parcels")
	for parcel: Entity in parcels:
		_check(parcel as Node as RigidBody3D != null, String(key) + ": parcel uses native body")


func _catalog_present(hall: Node) -> bool:
	var supply: DEF_Delivery = load(
		"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
	) as DEF_Delivery
	var count: int = 0
	for definition: DEF_InventoryItem in supply.order_catalog:
		var body: Node = hall.get_node_or_null(
			"Entityes/ItemCatalog/Item_" + String(definition.key)
		)
		if (
			body == null or not body is RigidBody3D
			or body.scene_file_path != definition.world_pickup_scene
		):
			return false
		count += 1
	var portals: Node = hall.get_node_or_null("Entityes/NpcRoomPortals")
	return count == 16 and portals != null and portals.get_child_count() == 10
#endregion
