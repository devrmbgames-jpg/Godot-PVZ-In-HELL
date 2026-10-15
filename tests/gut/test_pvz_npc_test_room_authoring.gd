extends GutTest
## Native preset/packing, bounded destinations and source isolation; no editor writes.

const TOOL: GDScript = preload("res://addons/pvz_ai_tools/npc_test_room_authoring_tool.gd")
const HALL: PackedScene = preload("res://content/scenes/primitive_test_level.tscn")


#region Typed presets and closed guard
func test_native_authoring_refuses_gameplay_process_before_any_writes() -> void:
	var tool: RefCounted = TOOL.new()
	var refused: Dictionary = tool.author({ "room_key": "brute" }, null)
	assert_false(refused.data.ok)
	assert_true(String(refused.data.error).contains("native editor"))
	var attendance_refusal: Dictionary = tool.author_room_attendance({ "room_key": "lost" }, null)
	assert_false(attendance_refusal.data.ok)
	assert_true(String(attendance_refusal.data.error).contains("native editor"))
	var supply_refusal: Dictionary = tool.author_room_supply({ "room_key": "lost" }, null)
	assert_false(supply_refusal.data.ok)
	assert_true(String(supply_refusal.data.error).contains("native editor"))
	var metadata_refusal: Dictionary = tool.author_hall_identities({ }, null)
	assert_false(metadata_refusal.data.ok)
	assert_true(String(metadata_refusal.data.error).contains("native editor"))


## Native resource authoring rejects malformed or ambiguous catalogs before mutations.
func test_supply_catalog_preflight_rejects_invalid_paths_and_duplicate_items() -> void:
	var clothing: String = "res://content/domains/inventory/definitions/def_item_work_clothes.tres"
	var valid: Array[DEF_InventoryItem] = TOOL.catalog_items(PackedStringArray([clothing]))
	assert_eq(valid.size(), 1)
	assert_eq(valid[0].categories, DEF_InventoryItem.Category.CLOTHING)
	assert_true(TOOL.catalog_items(PackedStringArray()).is_empty())
	assert_true(TOOL.catalog_items(PackedStringArray([clothing, clothing])).is_empty())
	assert_true(TOOL.catalog_items(PackedStringArray(["res://project.godot"])).is_empty())
	assert_true(TOOL.catalog_items(PackedStringArray([clothing + ".missing"])).is_empty())
	var excessive: PackedStringArray = []
	excessive.resize(PackageOrderRules.MAX_CATALOG_ITEMS + 1)
	assert_true(TOOL.catalog_items(excessive).is_empty())


func test_identity_preflight_is_atomic_and_preserves_existing_authored_metadata() -> void:
	var supply: DEF_Delivery = load(
		"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
	) as DEF_Delivery
	var hall: Node = HALL.instantiate()
	var first: Node = hall.get_node("Entityes/ItemCatalog/Item_axe")
	var last: Node = hall.get_node("Entityes/ItemCatalog/Item_toy_block")
	first.remove_meta(PlacedIdentityRules.LOCAL_ID_META)
	var original_id: StringName = last.get_meta(PlacedIdentityRules.LOCAL_ID_META)
	last.set_meta(PlacedIdentityRules.LOCAL_ID_META, &"owner_custom_id")
	var refused: Dictionary = TOOL.identity_plan(hall, supply.order_catalog)
	assert_false(refused.ok, "A later conflicting ID rejects the entire catalog")
	assert_false(
		first.has_meta(PlacedIdentityRules.LOCAL_ID_META),
		"Preflight performs no partial write",
	)
	assert_eq(last.get_meta(PlacedIdentityRules.LOCAL_ID_META), &"owner_custom_id")
	last.set_meta(PlacedIdentityRules.LOCAL_ID_META, original_id)
	var plan: Dictionary = TOOL.identity_plan(hall, supply.order_catalog)
	assert_true(plan.ok)
	assert_eq(plan.nodes.size(), 1, "Existing canonical IDs are untouched")
	assert_eq(plan.nodes[0], first)
	assert_eq(plan.keys[0], &"qa_item_axe")
	assert_false(first.has_meta(PlacedIdentityRules.LOCAL_ID_META))
	last.scene_file_path = "res://content/domains/interaction/entities/box.tscn"
	assert_false(
		TOOL.identity_plan(hall, supply.order_catalog).ok,
		"Replaced physical prefab refuses",
	)
	hall.free()


func test_unknown_destination_is_rejected_before_editor_access() -> void:
	var tool: RefCounted = TOOL.new()
	var refused: Dictionary = tool.author({ "room_key": "../main_level" }, null)
	assert_false(refused.data.ok)
	assert_true(refused.data.has("error"))
	assert_null(TOOL.make_preset(&"../main_level"))
	assert_eq(GameSessionService.test_room_path(&"../main_level"), "")
	assert_false(GameSessionService.is_test_room(GameSessionService.MAIN_LEVEL))


func test_all_ten_presets_keep_original_rules_and_supply_two_cases_daily() -> void:
	assert_eq(GameSessionService.TEST_ROOM_KEYS.size(), 10)
	for key: StringName in GameSessionService.TEST_ROOM_KEYS:
		var preset: DEF_NpcTestRoom = TOOL.make_preset(key)
		assert_not_null(preset)
		var original_path: String = (
			"res://content/domains/npc/definitions/def_npc_archetype_%s.tres" % key
		)
		var original: DEF_NpcArchetype = load(original_path)
		assert_eq(preset.district.profiles.size(), 1)
		var profile: DEF_NpcArchetype = preset.district.profiles[0]
		assert_ne(profile, original, "Fixture cannot mutate the production profile")
		assert_eq(profile.key, original.key)
		assert_eq(profile.rules, original.rules)
		assert_eq(profile.dialogue_variants, original.dialogue_variants)
		assert_eq(profile.optional_traits, original.optional_traits)
		assert_eq(preset.district.resident_count, 1)
		assert_eq(preset.district.visitor_count, 0)
		for phase: C_DayCycle.Phase in [
			C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING,
		]:
			assert_eq(profile.schedule.location_for(1, phase), DEF_NpcSchedule.Location.STREET)
		assert_gt(preset.district.place_for(&"home").position.y, 0.0)
		assert_eq(preset.schedule.supply.maximum_batch_packages, 2)
		assert_eq(preset.schedule.supply.packages.size(), 2)
		assert_eq(preset.schedule.events.size(), 2)
		for parcel: DEF_Package in preset.schedule.supply.packages:
			assert_eq(parcel.recipient_id, profile.recipient_key)
		for event: DEF_CustomerEvent in preset.schedule.events:
			assert_eq(event.arrival_delay_days, 0)
			assert_true(event.requires_registered_package)
		assert_eq(GameSessionService.manual_path(GameSessionService.test_room_path(key)), "")
		assert_eq(GameSessionService.autosave_path(GameSessionService.test_room_path(key)), "")
#endregion


#region Real native packed output and ownership
func test_packed_room_retains_core_prefabs_and_owned_return_portal_children() -> void:
	var preset: DEF_NpcTestRoom = TOOL.make_preset(&"weeping_angel")
	var root: Node3D = TOOL.build_room(HALL, preset)
	assert_not_null(root)
	assert_eq(root.get("autosave_path"), "")
	assert_null(root.get_node_or_null("Entityes/Trader"))
	assert_not_null(root.get_node_or_null("District"))
	assert_null(root.get_node_or_null("PVZ/Pedestal4"), "Room spawn is clear of hall displays")
	assert_eq((root.get_node("TruckParking") as Marker3D).position, Vector3(-3, 0.35, -23))
	var light_count: int = 0
	for child: Node in root.get_children():
		if child is NpcLightZone:
			light_count += 1
	assert_eq(light_count, 1, "Captured hall already has its controlled warehouse light")
	assert_eq(root.get("world"), root.get_node("World"))
	var session: Entity = root.get_node("Entityes/DaySession") as Entity
	var population: C_District = null
	var flow: C_CustomerFlow = null
	for recipe: Component in session.component_resources:
		if recipe is C_District:
			population = recipe as C_District
		if recipe is C_CustomerFlow:
			flow = recipe as C_CustomerFlow
	assert_eq(population.definition, preset.district)
	assert_eq(flow.schedule, preset.schedule)
	var packed: PackedScene = PackedScene.new()
	assert_eq(packed.pack(root), OK)
	root.free()
	var restored: Node3D = packed.instantiate() as Node3D
	assert_eq(restored.get("world"), restored.get_node("World"))
	var portal: Entity = restored.get_node("Entityes/ReturnPortal") as Entity
	assert_not_null(portal.get_node_or_null("Collision"))
	assert_not_null(portal.get_node_or_null("Visual"))
	assert_not_null(portal.get_node_or_null("Label"))
	var actions: C_InteractionActionSet = portal.component_resources[1] as C_InteractionActionSet
	assert_eq((actions.actions[0] as DEF_TestRoomAction).room_key, &"")
	restored.free()


func test_portal_is_real_solid_native_actor_and_uses_context_interaction() -> void:
	var root: Node3D = TOOL.make_portal(&"brute", "Громила")
	var body: StaticBody3D = root as StaticBody3D
	var actor: Entity = root as Node as Entity
	assert_eq(body.collision_layer, 2)
	assert_true(actor.component_resources[0] is C_Interactable)
	var actions: C_InteractionActionSet = actor.component_resources[1] as C_InteractionActionSet
	var action: DEF_TestRoomAction = actions.actions[0] as DEF_TestRoomAction
	assert_eq(action.slot, DEF_InteractionAction.Slot.INTERACT)
	assert_eq(action.room_key, &"brute")
	assert_eq(actions.reserved_slots, 1)
	assert_true((root.get_node("Collision") as CollisionShape3D).shape is BoxShape3D)
	assert_true((root.get_node("Label") as Label3D).text.contains("Громила"))
	root.free()
#endregion
