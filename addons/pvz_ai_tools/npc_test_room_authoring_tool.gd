@tool
extends RefCounted
## Bounded editor-only native QA room authoring; never runs inside a gameplay scene.

const SOURCE: String = "res://content/scenes/primitive_test_level.tscn"
const DIRECTORY: String = "res://content/scenes/npc_test_rooms"
const MORNING_SUPPLY: DEF_Delivery = preload(
	"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
)
const ROOM_SPAWN_CLEARANCE: float = 0.05
const ENTITY_SCRIPT: GDScript = preload("res://addons/gecs/ecs/entity.gd")
const KEEP_ACTORS: Array[StringName] = [
	&"Player",
	&"DeliveryCounter",
	&"Terminal",
	&"Scanner",
	&"ReceivingZone",
	&"DaySession",
	&"ShiftConsole",
	&"SleepPoint",
	&"LightSwitch",
	&"Shelves",
	&"NumberedShelves",
	&"InspectionBooth1",
	&"InspectionBooth2",
]
const DISPLAY_NAMES: Dictionary[StringName, String] = {
	&"night_hunter": "Ночной охотник",
	&"fire_elemental": "Огненный элементаль",
	&"shy": "Стеснительный",
	&"creepy": "Жуткий",
	&"brute": "Громила",
	&"hag": "Карга",
	&"weeping_angel": "Плачущий ангел",
	&"lost": "Заблудший",
	&"chain_devil": "Цепной дьявол",
	&"vampire": "Вампир",
}


#region Guarded native editor operation
## Creates one new fixed destination/preset/portal; all paths are closed, never overwritten.
func author(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	var key: StringName = StringName(params.get("room_key", ""))
	if key not in GameSessionService.TEST_ROOM_KEYS:
		return _refusal("Unknown canonical test room.")
	if not Engine.is_editor_hint():
		return _refusal("Room authoring is available only in the native editor.")
	var source_root: Node = EditorInterface.get_edited_scene_root()
	if source_root == null or source_root.scene_file_path != SOURCE:
		return _refusal("Open the native primitive test hall before authoring a room.")
	if EditorInterface.get_unsaved_scenes().has(SOURCE):
		return _refusal("The source hall has unsaved editor changes.")
	if String(params.get("source_fingerprint", "")) != FileAccess.get_sha256(SOURCE):
		return _refusal("The saved source hall fingerprint changed.")
	var targets: Array[String] = [
		GameSessionService.test_room_path(key),
		DIRECTORY.path_join("def_npc_test_room_" + String(key) + ".tres"),
		DIRECTORY.path_join(String(key) + "_portal.tscn"),
	]
	for target: String in targets:
		if FileAccess.file_exists(target):
			return _refusal("Target already exists; no authoring overwrite: " + target)
	var source: PackedScene = PackedScene.new()
	if source.pack(source_root) != OK:
		return _refusal("Could not capture the native edited source.")
	var preset: DEF_NpcTestRoom = make_preset(key)
	if preset == null:
		return _refusal("Canonical source assets did not produce a valid preset.")
	var room: Node3D = build_room(source, preset)
	var portal: Node3D = make_portal(key, preset.display_name)
	if room == null:
		portal.free()
		return _refusal("Native room contract does not match the captured source.")
	var packed: PackedScene = PackedScene.new()
	var packed_portal: PackedScene = PackedScene.new()
	var room_error: Error = packed.pack(room)
	var portal_error: Error = packed_portal.pack(portal)
	room.free()
	portal.free()
	if room_error != OK or portal_error != OK:
		return _refusal("Native scene packing failed before file writes.")
	var save_error: Error = ResourceSaver.save(preset, targets[1])
	if save_error == OK:
		save_error = ResourceSaver.save(packed, targets[0])
	if save_error == OK:
		save_error = ResourceSaver.save(packed_portal, targets[2])
	if save_error != OK:
		return {
			"data": { "ok": false, "error": error_string(save_error), "created_paths": targets }
		}
	EditorInterface.get_resource_filesystem().scan()
	return {
		"data": {
			"ok": true,
			"created": targets,
			"room_key": String(key),
			"cleanup": { "rm": targets },
			"undoable": false,
		}
	}


## Repairs only the open canonical room's isolated attendance, never production archetypes.
func author_room_attendance(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	if not Engine.is_editor_hint():
		return _refusal("Attendance authoring requires the native editor.")
	var key: StringName = StringName(params.get("room_key", ""))
	var expected: String = GameSessionService.test_room_path(key)
	var root: Node = EditorInterface.get_edited_scene_root()
	if expected.is_empty() or root == null or root.scene_file_path != expected:
		return _refusal("Open the requested canonical NPC room.")
	if EditorInterface.get_unsaved_scenes().has(expected):
		return _refusal("Save the room before attendance authoring.")
	if params.get("scene_fingerprint", "") != FileAccess.get_sha256(expected):
		return _refusal("The saved room fingerprint changed.")
	var preset_path: String = DIRECTORY.path_join("def_npc_test_room_" + String(key) + ".tres")
	if params.get("preset_fingerprint", "") != FileAccess.get_sha256(preset_path):
		return _refusal("The saved preset fingerprint changed.")
	var preset: DEF_NpcTestRoom = root.get_meta("npc_test_room", null) as DEF_NpcTestRoom
	var external: DEF_NpcTestRoom = load(preset_path) as DEF_NpcTestRoom
	var session: Entity = root.get_node_or_null("Entityes/DaySession") as Entity
	if preset == null or external == null or session == null:
		return _refusal("Missing native room preset or session.")
	var districts: Array[DEF_District] = [preset.district, external.district]
	for recipe: Component in session.component_resources:
		if recipe is C_District:
			districts.append((recipe as C_District).definition)
	if districts.size() != 3:
		return _refusal("Expected exactly one native district recipe.")
	for district: DEF_District in districts:
		if (
			district == null or district.profiles.size() != 1
			or district.profiles[0].schedule == null
			or district.key != StringName("qa_room/" + String(key))
			or district.place_for(&"home") == null
			or district.place_for(&"home").resource_path.get_slice("::", 0)
			not in [expected, preset_path]
			or district.profiles[0].schedule.resource_path.get_slice("::", 0)
			not in [expected, preset_path]
		):
			return _refusal("The isolated district contract changed.")
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	manager.create_action("Keep isolated test NPC present", UndoRedo.MERGE_DISABLE, root)
	var homes: Array[DEF_DistrictPlace] = []
	var schedules: Array[DEF_NpcSchedule] = []
	for district: DEF_District in districts:
		var home: DEF_DistrictPlace = district.place_for(&"home")
		if not homes.has(home):
			homes.append(home)
			var spawn: Vector3 = home.position
			spawn.y = ROOM_SPAWN_CLEARANCE
			manager.add_do_property(home, &"position", spawn)
			manager.add_undo_property(home, &"position", home.position)
		var attendance: DEF_NpcSchedule = district.profiles[0].schedule
		if schedules.has(attendance):
			continue
		schedules.append(attendance)
		for field: StringName in [&"morning", &"day", &"evening"]:
			manager.add_do_property(attendance, field, DEF_NpcSchedule.Location.STREET)
			manager.add_undo_property(attendance, field, attendance.get(field))
	manager.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	var saved: Error = ResourceSaver.save(external, preset_path)
	if saved != OK:
		return _refusal("Native preset save failed: " + error_string(saved))
	return { "data": { "ok": true, "room_key": key, "undoable": false, "save_scene": expected } }


static func _refusal(message: String) -> Dictionary:
	return { "data": { "ok": false, "error": message } }
#endregion


#region Native typed preset construction
## Creates detached immutable authoring data; canonical definitions and runtime state are untouched.
static func make_preset(key: StringName) -> DEF_NpcTestRoom:
	if key not in GameSessionService.TEST_ROOM_KEYS:
		return null
	var profile_path: String = (
		"res://content/domains/npc/definitions/def_npc_archetype_" + String(key) + ".tres"
	)
	var original: DEF_NpcArchetype = load(profile_path) as DEF_NpcArchetype
	var original_schedule: DEF_CustomerSchedule = load(
		"res://content/domains/customers/definitions/def_customer_schedule_default.tres"
	) as DEF_CustomerSchedule
	var original_supply: DEF_Delivery = MORNING_SUPPLY
	if (
		original == null or original_schedule == null or original_schedule.events.is_empty()
		or original_supply == null or original_supply.packages.size() < 2
	):
		return null
	var profile: DEF_NpcArchetype = original.duplicate(false) as DEF_NpcArchetype
	profile.resident = true
	profile.merchant = false
	var attendance: DEF_NpcSchedule = original.schedule.duplicate(false) as DEF_NpcSchedule
	attendance.weekdays = PackedInt32Array([0, 1, 2, 3, 4, 5, 6])
	attendance.morning = DEF_NpcSchedule.Location.STREET
	attendance.day = DEF_NpcSchedule.Location.STREET
	attendance.evening = DEF_NpcSchedule.Location.STREET
	profile.schedule = attendance
	var district: DEF_District = DEF_District.new()
	district.key = StringName("qa_room/" + String(key))
	district.profiles = [profile]
	district.resident_count = 1
	district.visitor_count = 0
	district.maximum_conflict_initiators = 0
	district.places = [
		_place(
			&"home", DEF_DistrictPlace.Kind.HOME,
			Vector3(-12, ROOM_SPAWN_CLEARANCE, 6), "Дом посетителя",
		),
		_place(&"portal", DEF_DistrictPlace.Kind.PORTAL, Vector3(-10, 0, -2), "Вход"),
		_place(&"walk", DEF_DistrictPlace.Kind.ACTIVITY, Vector3(-6, 0, 4), "Прогулка"),
		_place(&"shop", DEF_DistrictPlace.Kind.SHOP, Vector3(-6, 0, 8), "Место ожидания"),
		_place(&"shade", DEF_DistrictPlace.Kind.COVER, Vector3(-10, 0, 4), "Тень"),
	]
	district.shade_refuge = &"shade"
	var supply: DEF_Delivery = DEF_Delivery.new()
	supply.key = StringName("qa_supply/" + String(key))
	supply.maximum_batch_packages = 2
	supply.order_catalog = original_supply.order_catalog.duplicate()
	var schedule: DEF_CustomerSchedule = DEF_CustomerSchedule.new()
	schedule.key = StringName("qa_schedule/" + String(key))
	schedule.supply = supply
	schedule.customer_scene = original_schedule.customer_scene
	schedule.arrival_interval_seconds = 1.0
	for index: int in 2:
		var parcel: DEF_Package = original_supply.packages[index].duplicate(false)
		parcel.key = StringName("qa_parcel_%d" % (index + 1))
		parcel.recipient_id = profile.recipient_key
		supply.packages.append(parcel)
		var event: DEF_CustomerEvent = DEF_CustomerEvent.new()
		event.package_key = parcel.key
		event.arrival_delay_days = 0
		event.customer = original_schedule.events[0].customer
		schedule.events.append(event)
	var preset: DEF_NpcTestRoom = DEF_NpcTestRoom.new()
	preset.room_key = key
	preset.display_name = DISPLAY_NAMES[key]
	preset.district = district
	preset.schedule = schedule
	return preset


static func _place(
	key: StringName,
	kind: DEF_DistrictPlace.Kind,
	at: Vector3,
	caption: String,
) -> DEF_DistrictPlace:
	var place: DEF_DistrictPlace = DEF_DistrictPlace.new()
	place.key = key
	place.kind = kind
	place.position = at
	place.display_name = caption
	return place
#endregion


#region Detached native graph construction
## Clones editable native source geometry/prefabs; strips unrelated fixtures and the merchant.
static func build_room(source: PackedScene, preset: DEF_NpcTestRoom) -> Node3D:
	var root: Node3D = source.instantiate() as Node3D
	if (
		root == null or not root.has_node("Entityes/DaySession")
		or not root.has_node("Entityes/ReceivingZone") or not root.has_node("World")
	):
		if root != null:
			root.free()
		return null
	root.scene_file_path = ""
	root.name = "NpcTestRoom"
	root.set("autosave_path", "")
	root.set_meta("persistent_world_id", StringName("qa_room_" + String(preset.room_key)))
	root.set_meta("npc_test_room", preset)
	var actors: Node = root.get_node("Entityes")
	for child: Node in actors.get_children():
		if child.name not in KEEP_ACTORS:
			child.free()
	# Empty display supports from the hall must not obstruct isolated NPC spawn or activity.
	for support: Node in root.get_node("PVZ").get_children():
		if (
			support.name in [
				&"Pedestal1", &"Pedestal2", &"Pedestal3", &"Pedestal4", &"Pedestal5", &"Pedestal6",
			]
			or String(support.name).begins_with("Pedestal_catalog_")
		):
			support.free()
	(root.get_node("TruckParking") as Marker3D).position = Vector3(-3, 0.35, -23)
	var session: Entity = root.get_node("Entityes/DaySession") as Entity
	var recipes: Array[Component] = []
	var has_flow: bool = false
	for original: Component in session.component_resources:
		if original is C_District:
			continue
		var recipe: Component = original.duplicate(true) as Component
		if recipe is C_CustomerFlow:
			(recipe as C_CustomerFlow).schedule = preset.schedule
			has_flow = true
		recipes.append(recipe)
	if not has_flow:
		root.free()
		return null
	var population: C_District = C_District.new()
	population.definition = preset.district
	recipes.append(population)
	session.component_resources = recipes
	var enabled_traits: Array[EntityTrait] = session.traits.duplicate()
	var roster: EntityTrait = load(
		"res://content/domains/npc/authoring/et_district_session_district_roster.tres"
	) as EntityTrait
	enabled_traits.append(roster)
	session.traits = enabled_traits
	(root.get_node("Entityes/ReceivingZone") as E_ReceivingZone).supply = preset.schedule.supply
	var district_root: Node3D = Node3D.new()
	district_root.name = "District"
	root.add_child(district_root)
	district_root.owner = root
	var signs: Node = root.get_node_or_null("Signs")
	if signs != null:
		signs.free()
	var return_portal: Node3D = make_portal(&"", "Вернуться в тестовый зал")
	return_portal.name = "ReturnPortal"
	return_portal.position = Vector3(-16, 0, -12)
	actors.add_child(return_portal)
	return_portal.owner = root
	for child: Node in return_portal.get_children():
		child.owner = root
	var label: Label3D = Label3D.new()
	label.name = "RoomLabel"
	label.text = preset.display_name + "\nДве посылки в день. Каждый вход начинает новый тест."
	label.position = Vector3(0, 3, -10)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.005
	root.add_child(label)
	label.owner = root
	if root.get_node_or_null("WarehouseLightZone") == null:
		var light_scene: PackedScene = load(
			"res://content/scenes/npc_test_rooms/warehouse_light_zone.tscn"
		) as PackedScene
		var light: Node = light_scene.instantiate()
		root.add_child(light)
		light.owner = root
	return root


## Builds a native solid interaction prefab with authored action and Label3D, without custom input.
static func make_portal(key: StringName, caption: String) -> Node3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.set_script(ENTITY_SCRIPT)
	var actor: Entity = body as Node as Entity
	body.name = "TestRoomPortal"
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("persistent_local_id", StringName("qa_portal_" + String(key)))
	var action: DEF_TestRoomAction = DEF_TestRoomAction.new()
	action.room_key = key
	action.action_id = &"enter_test_room"
	action.slot = DEF_InteractionAction.Slot.INTERACT
	action.caption = "Войти: " + caption if key != &"" else caption
	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	actions.actions = [action]
	actions.reserved_slots = 1
	actor.component_resources = [C_Interactable.new(), actions]
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.8, 2.0, 0.2)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	collision.position.y = 1.0
	body.add_child(collision)
	collision.owner = body
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = shape.size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.3, 0.42)
	mesh.material = material
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = mesh
	visual.position.y = 1.0
	body.add_child(visual)
	visual.owner = body
	var label: Label3D = Label3D.new()
	label.name = "Label"
	label.position = Vector3(0, 1.4, -0.13)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.text = caption + "\nВход сбрасывает комнату" if key != &"" else caption
	label.font_size = 32
	label.pixel_size = 0.003
	body.add_child(label)
	label.owner = body
	return body
#endregion


#region Native hall metadata unavailable through standard property tools
## Installs missing canonical item IDs in one scene-owned undo action after whole-set preflight.
func author_hall_identities(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	if not Engine.is_editor_hint():
		return _refusal("Hall identity authoring requires the native editor.")
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != SOURCE:
		return _refusal("Open the native test hall.")
	if EditorInterface.get_unsaved_scenes().has(SOURCE):
		return _refusal("Save the hall before metadata authoring.")
	if params.get("source_fingerprint", "") != FileAccess.get_sha256(SOURCE):
		return _refusal("The saved hall fingerprint changed.")
	var supply: DEF_Delivery = MORNING_SUPPLY
	var prepared: Dictionary = identity_plan(root, supply.order_catalog)
	if not prepared.ok:
		return { "data": prepared }
	var nodes: Array[Node] = []
	var keys: Array[StringName] = []
	nodes.assign(prepared.nodes)
	keys.assign(prepared.keys)
	if nodes.is_empty():
		return { "data": { "ok": true, "authored": 0, "undoable": false } }
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	manager.create_action("Author test catalog identities", UndoRedo.MERGE_DISABLE, root)
	for index: int in nodes.size():
		manager.add_do_method(
			nodes[index],
			&"set_meta",
			PlacedIdentityRules.LOCAL_ID_META,
			keys[index],
		)
		manager.add_undo_method(nodes[index], &"remove_meta", PlacedIdentityRules.LOCAL_ID_META)
	manager.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	return { "data": { "ok": true, "authored": nodes.size(), "undoable": true } }


## Pure whole-set preflight refuses missing/replaced props and preserves existing authored IDs.
static func identity_plan(root: Node, definitions: Array[DEF_InventoryItem]) -> Dictionary:
	if definitions.is_empty() or definitions.size() > 32:
		return { "ok": false, "error": "Expected one through32 canonical catalog items." }
	var nodes: Array[Node] = []
	var keys: Array[StringName] = []
	for definition: DEF_InventoryItem in definitions:
		var actor: Node = root.get_node_or_null(
			"Entityes/ItemCatalog/Item_" + String(definition.key)
		)
		var key: StringName = StringName("qa_item_" + String(definition.key))
		if (
			actor == null or not actor is RigidBody3D
			or actor.scene_file_path != definition.world_pickup_scene
		):
			return {
				"ok": false,
				"error": "Canonical physical scene missing: " + String(definition.key),
			}
		if actor.has_meta(PlacedIdentityRules.LOCAL_ID_META):
			if StringName(actor.get_meta(PlacedIdentityRules.LOCAL_ID_META)) != key:
				return {
					"ok": false,
					"error": "An existing authored ID differs: " + String(definition.key),
				}
			continue
		nodes.append(actor)
		keys.append(key)
	return { "ok": true, "nodes": nodes, "keys": keys }
#endregion
