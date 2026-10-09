extends GutTest
## Current-format fixture: real retained NPC bodies, durable links and codec path coverage.

const SLOT_PATH: String = "user://gut_refactoring_v2_phase1.pvzh"
const SNAPSHOT_PATH: String = "res://tests/fixtures/refactoring_v2/current_snapshot.variant"
const MANIFEST_PATH: String = "res://tests/fixtures/refactoring_v2/save_visible_paths.json"
const MORNING_DAY: int = 2

var _fixture_root: Node3D
var _fixture_world: World
var _district: C_District
var _dormant_id: StringName
var _active_id: StringName


#region Isolated fixture construction
## Builds a deterministic authored session with real population and physical link endpoints.
func before_each() -> void:
	_fixture_root = Node3D.new()
	_fixture_root.name = "Phase1Fixture"
	add_child(_fixture_root)
	var district_marker: Node3D = Node3D.new()
	district_marker.name = "District"
	_fixture_root.add_child(district_marker)
	_fixture_world = World.new()
	_fixture_root.add_child(_fixture_world)
	ECS.world = _fixture_world
	NpcCustomerComposition.install(_fixture_world)
	_fixture_world.add_observer(O_InventoryLifecycle.new())
	_fixture_world.add_observer(O_DistrictLifecycle.new())
	_fixture_world.add_observer(O_CustomerPlanning.new())

	_district = C_District.new()
	_district.definition = load("res://content/domains/npc/definitions/def_district_default.tres") as DEF_District
	var session: Entity = Entity.new()
	session.name = "Session"
	session.component_resources = [_district, C_DayCycle.new(), C_Wallet.new(), C_PackageLedger.new(), C_Receiving.new(), C_Commerce.new()]
	_fixture_root.add_child(session)
	session.owner = _fixture_root
	_fixture_root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
	session.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(session.name))
	assert_true(PlacedIdentityRules.compile_for(_fixture_root).is_empty())
	_fixture_world.add_entity(session, null, false)
	_district = session.get_component(C_District) as C_District
	var calendar: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	calendar.clock.world_seed = -42
	calendar.clock.elapsed_ticks = 123_456_789
	calendar.clock.tick_remainder = 0.625
	DistrictPopulationService.initialize()
	DistrictPopulationService.prepare_morning(MORNING_DAY)
	_district.people[0].activity_sequence = 19
	_district.people[0].cadence_elapsed_ticks = 12_345
	_district.people[0].cadence_sample_tick = calendar.clock.elapsed_ticks

	_active_id = _district.people[0].npc_id
	_dormant_id = _district.people[1].npc_id
	var active_body: E_DistrictNpc = NpcPopulationQueries.body_for(_active_id)
	var dormant_body: E_DistrictNpc = NpcPopulationQueries.body_for(_dormant_id)
	DistrictPopulationService.set_placement(_district.people[0], active_body, NpcRecord.Placement.STREET)
	DistrictPopulationService.set_placement(_district.people[1], dormant_body, NpcRecord.Placement.STREET)
	(dormant_body.get_component(C_Health) as C_Health).current = 41.0
	var food: DEF_InventoryItem = load("res://content/domains/inventory/definitions/def_item_npc_meat.tres") as DEF_InventoryItem
	var granted: bool = InventoryService.grant(dormant_body, food, 3)
	assert_true(granted, "Grant owned stack while the body is active")
	var owned_item: Entity = InventoryService.items(dormant_body)[0]
	var order_identity: C_PersistentIdentity = C_PersistentIdentity.new()
	order_identity.key = "order/fixture/order/1"
	owned_item.add_component(order_identity)
	DistrictPopulationService.set_placement(_district.people[1], dormant_body, NpcRecord.Placement.OUTSIDE)
	var memory: NpcMemory = NpcMemory.new()
	memory.actor_id = &"fixture/player"
	memory.incident_id = &"fixture/incident/1"
	_district.people[1].memories.append(memory)

	# Preserve selected record/Definition paths in actual serialized component fields.
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = &"fixture/payment/1"
	operation.amount = 17
	var wallet: C_Wallet = session.get_component(C_Wallet) as C_Wallet
	assert_eq(WalletService.apply(wallet, operation, 1), WalletService.Status.COMMITTED)
	var supply: DEF_Delivery = load("res://content/domains/packages/definitions/def_delivery_morning_supply.tres") as DEF_Delivery
	var batch: ReceivingBatch = ReceivingBatch.new()
	batch.day_index = MORNING_DAY
	batch.package_keys = [String(supply.packages[0].key)]
	batch.package_scenes = [String(supply.packages[0].scene_variants[0])]
	(session.get_component(C_Receiving) as C_Receiving).pending.append(batch)
	var package_scene: PackedScene = load(batch.package_scenes[0]) as PackedScene
	var package: E_Package = package_scene.instantiate() as E_Package
	package.package_id = "fixture/shipment/1"
	package.package_definition = supply.packages[0]
	_fixture_root.add_child(package)
	EntityCompositionFixture.register(_fixture_world, package, false)
	var history_record: PackageRegistrationRecord = PackageHistoryService.record_arrival(package, 1)
	assert_not_null(history_record)

	var commerce: C_Commerce = session.get_component(C_Commerce) as C_Commerce
	var receipt: PurchaseReceipt = PurchaseReceipt.new()
	receipt.operation_id = &"fixture/order/1"
	receipt.item_key = food.key
	receipt.mode = PurchaseReceipt.Mode.ORDER
	receipt.quantity = 3
	commerce.receipts.append(receipt)
	var delivery: PendingDelivery = PendingDelivery.new()
	delivery.delivery_id = receipt.operation_id
	delivery.item = food
	delivery.quantity = receipt.quantity
	delivery.fulfilled = true
	commerce.pending_deliveries.append(delivery)

	var slot: Entity = _placed("res://content/domains/interaction/entities/physical_slot.tscn", "Slot")
	var stored_box: Entity = _placed("res://content/domains/interaction/entities/anchorable_test_box.tscn", "StoredBox")
	var stored_link: Relationship = Relationship.new(R_StoredIn.new(), slot)
	stored_box.add_relationship(stored_link)
	var attached: bool = PhysicalSlotService.attach(stored_box, stored_link)
	assert_true(attached, "Attach stored physical box")
	var cart: Entity = _placed("res://content/domains/interaction/entities/push_cart.tscn", "Cart")
	# CharacterBody carts require an explicit persistent capability in this schema.
	var cart_identity: C_PersistentIdentity = C_PersistentIdentity.new()
	cart_identity.key = "fixture/cart"
	cart.add_component(cart_identity)
	var cargo_box: Entity = _placed("res://content/domains/interaction/entities/anchorable_test_box.tscn", "CargoBox")
	var cargo_data: R_CartCargo = R_CartCargo.new()
	cargo_data.local_pose = Transform3D.IDENTITY
	var cargo_link: Relationship = Relationship.new(cargo_data, cart)
	cargo_box.add_relationship(cargo_link)
	var loaded: bool = CartCargoService.cargo_added(cargo_box, cargo_link)
	assert_true(loaded, "Attach cart cargo")

	# Remove random GECS IDs from the golden fixture while maintaining its derived index.
	_fixture_world.entity_id_registry.clear()
	for index: int in _fixture_world.entities.size():
		var entity: Entity = _fixture_world.entities[index]
		entity.id = "fixture/entity/%d" % index
		_fixture_world.entity_id_registry[entity.id] = entity
		var body: RigidBody3D = entity as Node as RigidBody3D
		# Active cargo must retain the live integrator contract during restore.
		if body != null and CartCargoQueries.relationship(entity) == null:
			body.freeze = true


func _placed(scene_path: String, label: String) -> Entity:
	var packed: PackedScene = load(scene_path) as PackedScene
	var entity: Entity = packed.instantiate() as Entity
	entity.name = label
	_fixture_root.add_child(entity)
	entity.owner = _fixture_root
	_fixture_root.set_meta(PlacedIdentityRules.WORLD_ID_META, &"fixture")
	entity.set_meta(PlacedIdentityRules.LOCAL_ID_META, StringName(entity.name))
	assert_true(PlacedIdentityRules.compile_for(_fixture_root).is_empty())
	_fixture_world.add_entity(entity, null, false)
	return entity


## Removes only this test's isolated slot and world, leaving user autosave untouched.
func after_each() -> void:
	_fixture_world.purge(false)
	ECS.world = null
	_fixture_root.free()
	for path: String in [SLOT_PATH, SLOT_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
#endregion


#region Current-format roundtrip and rejection
## Reads the committed native-Variant fixture, writes an isolated slot and restores real links/bodies.
func test_current_format_fixture_roundtrip_and_retained_body_identity() -> void:
	var expected_roll: int = GameTimeQueries.decision(
		String(_active_id), MORNING_DAY, "npc/activity", 19,
	).randi()
	var snapshot: Dictionary = WorldSnapshotService.capture(_fixture_root, MORNING_DAY)
	assert_true(WorldSnapshotService.valid(snapshot, _fixture_root), "Captured data validates before golden write")
	var supported: bool = WorldSnapshotService.can_restore(snapshot, _fixture_root)
	assert_true(supported, "Captured prefab/role contracts validate")
	if not supported:
		return
	if OS.get_environment("PVZH_UPDATE_BASELINE") == "1":
		var fixture_file: FileAccess = FileAccess.open(SNAPSHOT_PATH, FileAccess.WRITE)
		fixture_file.store_string(var_to_str(snapshot))
		fixture_file.close()
	else:
		var decoded: Variant = str_to_var(FileAccess.get_file_as_string(SNAPSHOT_PATH))
		assert_true(decoded is Dictionary)
		if not decoded is Dictionary:
			return
		snapshot = decoded as Dictionary

	assert_eq(snapshot.version, AutosaveStore.SCHEMA_VERSION)
	assert_true(WorldSnapshotService.can_restore(snapshot, _fixture_root))
	assert_eq(AutosaveStore.write(snapshot, SLOT_PATH), OK)
	var stored_snapshot: Dictionary = AutosaveStore.read(SLOT_PATH)
	assert_eq(stored_snapshot, snapshot)
	var retained_body: E_DistrictNpc = NpcPopulationQueries.body_for(_dormant_id)
	assert_true(WorldSnapshotService.restore(stored_snapshot, _fixture_root))
	var restored_calendar: C_DayCycle = DayPhaseQueries.current()
	assert_eq(restored_calendar.clock.elapsed_ticks, 123_456_789)
	assert_eq(restored_calendar.clock.tick_remainder, 0.625)
	assert_eq(restored_calendar.clock.world_seed, -42)
	assert_eq(restored_calendar.day_index, MORNING_DAY)
	var restored_person: NpcRecord = NpcPopulationQueries.person_for(_active_id)
	assert_eq(restored_person.activity_sequence, 19)
	assert_eq(restored_person.cadence_elapsed_ticks, 12_345)
	assert_eq(restored_person.cadence_sample_tick, restored_calendar.clock.elapsed_ticks)
	assert_eq(GameTimeQueries.decision(
		String(_active_id), MORNING_DAY, "npc/activity", restored_person.activity_sequence,
	).randi(), expected_roll)

	var active_body: E_DistrictNpc = NpcPopulationQueries.body_for(_active_id)
	var dormant_body: E_DistrictNpc = NpcPopulationQueries.body_for(_dormant_id)
	assert_same(dormant_body, retained_body)
	assert_true(active_body.enabled)
	assert_false(dormant_body.enabled)
	assert_true((dormant_body as Node) is RigidBody3D)
	assert_eq((dormant_body.get_component(C_Health) as C_Health).current, 41.0)
	DistrictPopulationService.set_placement(NpcPopulationQueries.person_for(_dormant_id), dormant_body, NpcRecord.Placement.STREET)
	assert_eq(InventoryService.items(dormant_body).size(), 1)
	assert_eq(PhysicalSlotService.occupant(_fixture_root.get_node("Slot") as Entity), _fixture_root.get_node("StoredBox"))
	var cargo_box: Entity = _fixture_root.get_node("CargoBox") as Entity
	var cargo_link: Relationship = CartCargoQueries.relationship(cargo_box)
	assert_not_null(cargo_link)
	assert_true((cargo_link.relation as R_CartCargo).lifecycle_applied)
	var cart_state: C_CartTransport = (_fixture_root.get_node("Cart") as Entity).get_component(C_CartTransport) as C_CartTransport
	assert_true(cart_state.cargo.has(cargo_box))
	var matches: int = 0
	for entity: Entity in _fixture_world.entities:
		var identity: C_NpcIdentity = entity.get_component(C_NpcIdentity) as C_NpcIdentity
		if identity != null and identity.npc_id == _dormant_id:
			matches += 1
	assert_eq(matches, 1)


## Rejects unsupported versions and unresolved links without touching the live retained body.
func test_incompatible_and_unresolved_data_reject_before_live_mutation() -> void:
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(_dormant_id)
	var entity_count: int = _fixture_world.entities.size()
	var snapshot: Dictionary = WorldSnapshotService.capture(_fixture_root, MORNING_DAY)
	for version: int in [1, AutosaveStore.SCHEMA_VERSION - 1, AutosaveStore.SCHEMA_VERSION + 1]:
		var incompatible: Dictionary = snapshot.duplicate(true)
		incompatible.version = version
		assert_false(WorldSnapshotService.restore(incompatible, _fixture_root))
		assert_same(NpcPopulationQueries.body_for(_dormant_id), body)
		assert_eq(_fixture_world.entities.size(), entity_count)
		assert_eq(AutosaveStore.write(incompatible, SLOT_PATH), OK)
		var rejected_slot: PackedByteArray = FileAccess.get_file_as_bytes(SLOT_PATH)
		var autosave: C_Autosave = C_Autosave.new()
		autosave.path = SLOT_PATH
		assert_false(NightSaveService.restore_startup(_fixture_root, autosave))
		assert_eq(FileAccess.get_file_as_bytes(SLOT_PATH), rejected_slot)
		assert_same(NpcPopulationQueries.body_for(_dormant_id), body)

	var duplicate: Dictionary = snapshot.duplicate(true)
	(duplicate.entities as Array).append((duplicate.entities as Array)[0])
	assert_false(WorldSnapshotService.restore(duplicate, _fixture_root))
	assert_same(NpcPopulationQueries.body_for(_dormant_id), body)

	for record: Dictionary in snapshot.entities:
		if not (record.links as Array).is_empty():
			(record.links as Array)[0].target = "unresolved/fixture"
			break
	assert_false(WorldSnapshotService.restore(snapshot, _fixture_root))
	assert_same(NpcPopulationQueries.body_for(_dormant_id), body)
	assert_eq((body.get_component(C_Health) as C_Health).current, 41.0)
	assert_eq(_fixture_world.entities.size(), entity_count)
#endregion


#region Closed codec path inventory
## Exercises every declared Component/record script through the actual codec, including native field values.
func test_manifest_covers_runtime_codec_script_paths() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed is Dictionary)
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed as Dictionary
	assert_eq(int(manifest.schema), AutosaveStore.SCHEMA_VERSION)
	for entry: Dictionary in manifest.components:
		var script: Script = SaveDataCodec.component_script(String(entry.path))
		assert_not_null(script)
		var component: Component = script.new() as Component
		var encoded: Dictionary = SaveDataCodec.component_data(component)
		assert_eq(encoded.type, entry.path)
		assert_true(SaveDataCodec.complete_component_data(script, encoded.fields as Dictionary))
		var restored: Component = script.new() as Component
		assert_true(SaveDataCodec.apply_fields(restored, encoded.fields as Dictionary))
		assert_eq(SaveDataCodec.component_data(restored), encoded)
	for entry: Dictionary in manifest.records:
		var script: Script = SaveDataCodec.record_script(String(entry.path))
		assert_not_null(script)
		var record: Resource = script.new() as Resource
		var encoded: Variant = SaveDataCodec.encode(record)
		var restored: Variant = SaveDataCodec.decode(encoded)
		assert_true(restored is Resource)
		assert_eq(SaveDataCodec.encode(restored), encoded)
#endregion

#region Time snapshot rejection
## Malformed elapsed time or future NPC samples reject before changing the live clock/body state.
func test_invalid_time_snapshot_rejects_before_live_mutation() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_fixture_root, MORNING_DAY)
	var calendar: C_DayCycle = DayPhaseQueries.current()
	for scenario: int in 3:
		var malformed: Dictionary = snapshot.duplicate(true)
		for record: Dictionary in malformed.entities:
			for component: Dictionary in record.components:
				if String(component.type) == (C_DayCycle as Script).resource_path:
					var clock_fields: Dictionary = component.fields.clock.fields as Dictionary
					if scenario == 0:
						clock_fields.tick_remainder = 1.0
					elif scenario == 1:
						clock_fields.erase("world_seed")
				if scenario == 2 and String(component.type) == (C_District as Script).resource_path:
					var first_person: Dictionary = (component.fields.people as Array)[0] as Dictionary
					(first_person.fields as Dictionary).cadence_sample_tick = 123_456_790
		assert_false(WorldSnapshotService.restore(malformed, _fixture_root))
		assert_eq(calendar.clock.elapsed_ticks, 123_456_789)
		assert_eq(calendar.clock.tick_remainder, 0.625)
		assert_eq(NpcPopulationQueries.person_for(_active_id).cadence_sample_tick, 123_456_789)
#endregion
