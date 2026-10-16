extends GutTest
## Current-format fixture: real retained NPC bodies, durable links and codec path coverage.

const SLOT_PATH: String = "user://gut_refactoring_v2_phase1.pvzh"
const SNAPSHOT_PATH: String = "res://tests/fixtures/refactoring_v2/current_snapshot.variant"
const MANIFEST_PATH: String = "res://tests/fixtures/refactoring_v2/save_visible_paths.json"
const MORNING_DAY: int = 2
const REACTIONS = preload("res://content/domains/customers/rules/customer_parcel_reaction_rules.gd")
const DEMAND = REACTIONS.DemandOutcome

var _fixture_root: Node3D
var _fixture_world: World
var _district: C_District
var _dormant_id: StringName
var _active_id: StringName


## Restores the same physical owner inside the actual demand release callback.
class RegripDuringDemand extends Observer:
	## Borrowed native fixture endpoints, valid until this observer is explicitly removed.
	var parcel: Entity
	## Same persistent receiver; a replacement grip must keep its incident reconstructible.
	var holder: E_DistrictNpc


	func query() -> QueryBuilder:
		return q.on_relationship_removed([R_HeldBy])


	func each(_event: Variant, subject: Entity, _payload: Variant = null) -> void:
		if subject == parcel:
			parcel.add_relationship(Relationship.new(R_HeldBy.new(), holder))


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
	_district.definition = (
		load("res://content/domains/npc/definitions/def_district_default.tres") as DEF_District
	)
	var session: Entity = Entity.new()
	session.name = "Session"
	session.component_resources = ([
		_district,
		C_DayCycle.new(),
		C_Wallet.new(),
		C_PackageLedger.new(),
		C_Receiving.new(),
		C_Commerce.new(),
	])
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
	DistrictPopulationService.set_placement(
		_district.people[0],
		active_body,
		NpcRecord.Placement.STREET,
	)
	DistrictPopulationService.set_placement(
		_district.people[1],
		dormant_body,
		NpcRecord.Placement.STREET,
	)
	(dormant_body.get_component(C_Health) as C_Health).current = 41.0
	var food: DEF_InventoryItem = (
		load("res://content/domains/inventory/definitions/def_item_npc_meat.tres")
		as DEF_InventoryItem
	)
	var granted: bool = InventoryService.grant(dormant_body, food, 3)
	assert_true(granted, "Grant owned stack while the body is active")
	var owned_item: Entity = InventoryService.items(dormant_body)[0]
	var order_identity: C_PersistentIdentity = C_PersistentIdentity.new()
	order_identity.key = "order/fixture/order/1"
	owned_item.add_component(order_identity)
	DistrictPopulationService.set_placement(
		_district.people[1],
		dormant_body,
		NpcRecord.Placement.OUTSIDE,
	)
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
	var supply: DEF_Delivery = (
		load("res://content/domains/packages/definitions/def_delivery_morning_supply.tres")
		as DEF_Delivery
	)
	var batch: ReceivingBatch = ReceivingBatch.new()
	batch.day_index = MORNING_DAY
	batch.package_keys = [String(supply.packages[0].key)]
	batch.package_scenes = [String(supply.packages[0].scene_variants[0])]
	batch.order_item_paths = [""]
	batch.order_quantities = [0]
	batch.order_packing_paths = [""]
	(session.get_component(C_Receiving) as C_Receiving).pending.append(batch)
	var receiving: C_Receiving = session.get_component(C_Receiving) as C_Receiving
	receiving.last_started_day = MORNING_DAY
	receiving.batch_id = "fixture/cargo/2"
	receiving.cargo_batch_id = receiving.batch_id
	var cargo_receipt: TruckCargoReceipt = TruckCargoReceipt.new()
	cargo_receipt.batch_id = receiving.batch_id
	cargo_receipt.entity_id = "fixture/removed/cargo"
	cargo_receipt.day_index = MORNING_DAY
	cargo_receipt.kind = TruckCargoReceipt.Kind.SALE
	cargo_receipt.amount = 7
	cargo_receipt.removed = true
	receiving.cargo_receipts.append(cargo_receipt)
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

	var slot: Entity = (
		_placed("res://content/domains/interaction/entities/physical_slot.tscn", "Slot")
	)
	var stored_box: Entity = (
		_placed("res://content/domains/interaction/entities/anchorable_test_box.tscn", "StoredBox")
	)
	var stored_link: Relationship = Relationship.new(R_StoredIn.new(), slot)
	stored_box.add_relationship(stored_link)
	var attached: bool = PhysicalSlotService.attach(stored_box, stored_link)
	assert_true(attached, "Attach stored physical box")
	var cart: Entity = _placed("res://content/domains/interaction/entities/push_cart.tscn", "Cart")
	# CharacterBody carts require an explicit persistent capability in this schema.
	var cart_identity: C_PersistentIdentity = C_PersistentIdentity.new()
	cart_identity.key = "fixture/cart"
	cart.add_component(cart_identity)
	var cargo_box: Entity = (
		_placed("res://content/domains/interaction/entities/anchorable_test_box.tscn", "CargoBox")
	)
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
## Reads the committed native-Variant fixture, writes an isolated slot and restores real
## links/bodies.
func test_valid_snapshot_cannot_capture_or_restore_during_cargo_transaction() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_fixture_root, MORNING_DAY)
	assert_true(WorldSnapshotService.can_restore(snapshot, _fixture_root))
	var session: Entity = _fixture_world.query.with_all([C_Receiving]).execute_one()
	var receiving: C_Receiving = session.get_component(C_Receiving) as C_Receiving
	receiving.cargo_commit_in_progress = true
	assert_true(WorldSnapshotService.capture(_fixture_root, MORNING_DAY).is_empty())
	assert_false(WorldSnapshotService.can_restore(snapshot, _fixture_root))
	assert_false(WorldSnapshotService.restore(snapshot, _fixture_root))
	assert_true(receiving.cargo_commit_in_progress)
	receiving.cargo_commit_in_progress = false
	assert_true(WorldSnapshotService.can_restore(snapshot, _fixture_root))


func test_current_format_fixture_roundtrip_and_retained_body_identity() -> void:
	var expected_roll: int = GameTimeQueries \
			.decision(String(_active_id), MORNING_DAY, "npc/activity", 19) \
			.randi()
	var snapshot: Dictionary = WorldSnapshotService.capture(_fixture_root, MORNING_DAY)
	assert_true(
		WorldSnapshotService.valid(snapshot, _fixture_root),
		"Captured data validates before golden write",
	)
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
	assert_true(
		WorldSnapshotService.can_restore(snapshot, _fixture_root),
		"Golden snapshot data valid: %s" % WorldSnapshotService.valid(snapshot, _fixture_root),
	)
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
	var restored_zone: Entity = _fixture_world.query.with_all([C_Receiving]).execute_one()
	var restored_receiving: C_Receiving = restored_zone.get_component(C_Receiving) as C_Receiving
	assert_eq(restored_receiving.cargo_receipts.size(), 1)
	assert_true(restored_receiving.cargo_receipts[0].removed)
	assert_false(restored_receiving.cargo_receipts[0].settled)
	assert_eq(restored_receiving.cargo_receipts[0].amount, 7)
	var restored_person: NpcRecord = NpcPopulationQueries.person_for(_active_id)
	assert_eq(restored_person.activity_sequence, 19)
	assert_eq(restored_person.cadence_elapsed_ticks, 12_345)
	assert_eq(restored_person.cadence_sample_tick, restored_calendar.clock.elapsed_ticks)
	var restored_random: RandomNumberGenerator = GameTimeQueries.decision(
		String(_active_id),
		MORNING_DAY,
		"npc/activity",
		restored_person.activity_sequence,
	)
	assert_eq(restored_random.randi(), expected_roll)

	var active_body: E_DistrictNpc = NpcPopulationQueries.body_for(_active_id)
	var dormant_body: E_DistrictNpc = NpcPopulationQueries.body_for(_dormant_id)
	assert_same(dormant_body, retained_body)
	assert_true(active_body.enabled)
	assert_false(dormant_body.enabled)
	assert_true((dormant_body as Node) is RigidBody3D)
	assert_eq((dormant_body.get_component(C_Health) as C_Health).current, 41.0)
	DistrictPopulationService.set_placement(
		NpcPopulationQueries.person_for(_dormant_id),
		dormant_body,
		NpcRecord.Placement.STREET,
	)
	assert_eq(InventoryService.items(dormant_body).size(), 1)
	assert_eq(
		PhysicalSlotService.occupant(_fixture_root.get_node("Slot") as Entity),
		_fixture_root.get_node("StoredBox"),
	)
	var cargo_box: Entity = _fixture_root.get_node("CargoBox") as Entity
	var cargo_link: Relationship = CartCargoQueries.relationship(cargo_box)
	assert_not_null(cargo_link)
	assert_true((cargo_link.relation as R_CartCargo).lifecycle_applied)
	var cart_state: C_CartTransport = (
		(_fixture_root.get_node("Cart") as Entity).get_component(C_CartTransport) as C_CartTransport
	)
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
## A held incident reconstructs native ownership without replaying the recognition transaction.
func test_stolen_parcel_disk_roundtrip_restores_one_grip_on_retained_and_fresh_bodies() -> void:
	await _assert_stolen_parcel_roundtrip(DEMAND.NONE)


func test_pending_return_disk_roundtrip_preserves_choice_without_returning_the_body() -> void:
	await _assert_stolen_parcel_roundtrip(DEMAND.RETURN)


func test_attack_disk_roundtrip_preserves_captured_choice_without_replaying_combat() -> void:
	await _assert_stolen_parcel_roundtrip(DEMAND.ATTACK)


func test_same_npc_regrip_during_demand_survives_retained_and_fresh_disk_restore() -> void:
	await _assert_stolen_parcel_roundtrip(DEMAND.RETURN, true)


func _assert_stolen_parcel_roundtrip(
	demand: REACTIONS.DemandOutcome, regrip_during_demand: bool = false,
) -> void:
	_fixture_world.add_observer(O_GrabLifecycle.new())
	_fixture_world.add_observer(O_CustomerParcelIncidents.new())
	var session: Entity = _fixture_world.query.with_all([C_DayCycle]).execute_one()
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	session.add_component(flow)
	var parcel: Entity = PackageQueries.find_live_package("fixture/shipment/1")
	var holder: E_DistrictNpc = NpcPopulationQueries.body_for(_active_id)
	var holder_id: StringName = _active_id
	if regrip_during_demand:
		for person: NpcRecord in _district.people:
			if person.profile.key == &"archetype/brute":
				holder_id = person.npc_id
				holder = NpcPopulationQueries.body_for(holder_id)
				assert_true(DistrictPopulationService.set_placement(
					person, holder, NpcRecord.Placement.STREET, &"demand_fixture", true,
				))
				break
	(GrabQueries.physical_body(parcel)).freeze = false
	var binding: Relationship = Relationship.new(R_HeldBy.new(), holder)
	parcel.add_relationship(binding)
	assert_true((binding.relation as R_HeldBy).lifecycle_applied)
	var incident: CustomerParcelIncident = CustomerParcelIncident.new()
	incident.sequence = 1
	incident.npc_id = holder_id
	incident.package_id = "fixture/shipment/1"
	incident.visit_id = &"fixture/wrong-offer"
	incident.outcome = CustomerParcelReactionRules.Outcome.KEEP
	incident.phase = CustomerParcelIncident.Phase.HELD
	incident.created_tick = GameTimeQueries.current().elapsed_ticks
	incident.next_eligible_tick = incident.created_tick + CustomerParcelIncidentService.BLOCK_TICKS
	incident.demand_outcome = demand
	if demand != DEMAND.NONE:
		incident.demand_strength = 5.0
		incident.demand_roll = 0.1 if demand == DEMAND.ATTACK else 0.8
		incident.demand_tick = incident.created_tick
	flow.parcel_incident_sequence = 2
	flow.parcel_incidents.append(incident)
	if regrip_during_demand:
		var actor: E_DistrictNpc = NpcPopulationQueries.body_for(_active_id)
		actor.add_component(C_PlayerInputController.new())
		(actor.get_component(C_Strength) as C_Strength).value = 5.0
		actor.global_position = Vector3(1000.0, 0.0, 998.0)
		holder.global_position = Vector3(1000.0, 0.0, 1000.0)
		(GrabQueries.physical_body(parcel)).global_position = holder.hold_anchor.global_position
		var agent: C_CustomerAgent = C_CustomerAgent.new()
		agent.visit_id = incident.visit_id
		agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
		holder.add_component(agent)
		var visit: CustomerVisit = CustomerVisit.new()
		visit.visit_id = incident.visit_id
		visit.customer_id = holder_id
		visit.package_id = incident.package_id
		visit.started = true
		var schedule: DEF_CustomerSchedule = load(
			"res://content/domains/customers/definitions/def_customer_schedule_default.tres"
		) as DEF_CustomerSchedule
		visit.definition = schedule.events[0].customer
		flow.visits.append(visit)
		var observer: RegripDuringDemand = RegripDuringDemand.new()
		observer.parcel = parcel
		observer.holder = holder
		_fixture_world.add_observer(observer)
		assert_false(CustomerParcelDemandService.demand(actor, holder))
		_fixture_world.remove_observer(observer)
		assert_same(GrabQueries.held_object(holder), parcel)
		assert_eq(incident.phase, CustomerParcelIncident.Phase.HELD)
	var snapshot: Dictionary = WorldSnapshotService.capture(_fixture_root, MORNING_DAY)
	assert_true(WorldSnapshotService.can_restore(snapshot, _fixture_root))
	assert_eq(AutosaveStore.write(snapshot, SLOT_PATH), OK)
	var loaded: Dictionary = AutosaveStore.read(SLOT_PATH)
	for attempt: int in 2:
		GrabReleaseService.release(holder, parcel)
		assert_true(WorldSnapshotService.restore(loaded, _fixture_root, true))
		assert_same(GrabQueries.held_object(holder), parcel)
		var restored: C_CustomerFlow = CustomerFlowQueries.current()
		assert_eq(restored.parcel_incident_sequence, 2)
		assert_eq(restored.parcel_incidents[0].phase, CustomerParcelIncident.Phase.HELD)
		assert_eq(restored.parcel_incidents[0].next_eligible_tick, incident.next_eligible_tick)
		_assert_demand_data(restored.parcel_incidents[0], incident)
		assert_null(ThrowContext.relationship(parcel))
		assert_null(CombatQueries.target_for(holder))
	_fixture_world.remove_entity(holder)
	_fixture_world.remove_entity(parcel)
	await get_tree().process_frame
	assert_true(WorldSnapshotService.can_restore(loaded, _fixture_root))
	assert_true(WorldSnapshotService.restore(loaded, _fixture_root, true))
	holder = NpcPopulationQueries.body_for(holder_id)
	parcel = PackageQueries.find_live_package("fixture/shipment/1")
	assert_same(GrabQueries.held_object(holder), parcel)
	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	assert_eq(load_state.mass_kg, GrabQueries.physical_body(parcel).mass)
	assert_eq(CustomerFlowQueries.current().parcel_incident_sequence, 2)
	assert_false(CustomerFlowQueries.current().parcel_reaction_in_progress)
	_assert_demand_data(CustomerFlowQueries.current().parcel_incidents[0], incident)
	assert_null(CombatQueries.target_for(holder))


func _assert_demand_data(actual: CustomerParcelIncident, expected: CustomerParcelIncident) -> void:
	assert_eq(actual.demand_outcome, expected.demand_outcome)
	assert_eq(actual.demand_strength, expected.demand_strength)
	assert_eq(actual.demand_roll, expected.demand_roll)
	assert_eq(actual.demand_tick, expected.demand_tick)


func test_completed_demand_history_survives_disk_restore_without_live_endpoints() -> void:
	var session: Entity = _fixture_world.query.with_all([C_DayCycle]).execute_one()
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	session.add_component(flow)
	var now: int = GameTimeQueries.current().elapsed_ticks
	for demand: REACTIONS.DemandOutcome in [DEMAND.ATTACK, DEMAND.RETURN]:
		var incident: CustomerParcelIncident = CustomerParcelIncident.new()
		incident.sequence = flow.parcel_incident_sequence
		incident.npc_id = StringName("departed/receiver/%d" % incident.sequence)
		incident.package_id = "retired/parcel/%d" % incident.sequence
		incident.visit_id = &"previous/contact"
		incident.outcome = REACTIONS.Outcome.KEEP
		incident.created_tick = now - GameTimeRules.TICKS_PER_SECOND
		incident.next_eligible_tick = now + CustomerParcelIncidentService.BLOCK_TICKS
		incident.demand_outcome = demand
		incident.demand_strength = 5.0
		incident.demand_roll = 0.1 if demand == DEMAND.ATTACK else 0.8
		incident.demand_tick = now
		flow.parcel_incidents.append(incident)
		flow.parcel_incident_sequence += 1
	var snapshot: Dictionary = WorldSnapshotService.capture(_fixture_root, MORNING_DAY)
	assert_true(WorldSnapshotService.can_restore(snapshot, _fixture_root))
	assert_eq(AutosaveStore.write(snapshot, SLOT_PATH), OK)
	var loaded: Dictionary = AutosaveStore.read(SLOT_PATH)
	var entity_count: int = _fixture_world.entities.size()
	for attempt: int in 2:
		assert_true(WorldSnapshotService.restore(loaded, _fixture_root, true))
		assert_eq(_fixture_world.entities.size(), entity_count)
		var restored: C_CustomerFlow = CustomerFlowQueries.current()
		assert_eq(restored.parcel_incident_sequence, 3)
		for index: int in 2:
			_assert_demand_data(restored.parcel_incidents[index], flow.parcel_incidents[index])
			assert_eq(
				restored.parcel_incidents[index].phase,
				CustomerParcelIncident.Phase.COMPLETED,
			)


## Invalid incident data rejects before touching the actual World or the current pair journal.
func test_invalid_incident_shape_deadline_pair_and_held_endpoints_reject_before_mutation() -> void:
	var session: Entity = _fixture_world.query.with_all([C_DayCycle]).execute_one()
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	session.add_component(flow)
	var incident: CustomerParcelIncident = CustomerParcelIncident.new()
	incident.sequence = 1
	incident.npc_id = &"departed/receiver"
	incident.package_id = "destroyed/parcel"
	incident.visit_id = &"previous/contact"
	incident.created_tick = GameTimeQueries.current().elapsed_ticks
	incident.next_eligible_tick = incident.created_tick + CustomerParcelIncidentService.BLOCK_TICKS
	flow.parcel_incidents.append(incident)
	flow.parcel_incident_sequence = 2
	var snapshot: Dictionary = WorldSnapshotService.capture(_fixture_root, MORNING_DAY)
	assert_true(WorldSnapshotService.can_restore(snapshot, _fixture_root))
	var entity_count: int = _fixture_world.entities.size()
	for mutation: String in [
		"sequence", "future", "short", "duplicate", "missing", "held",
		"unattempted_strength", "unattempted_roll", "unattempted_tick", "demand_invalid",
		"demand_without_keep", "demand_future", "demand_before", "demand_wrong_choice",
		"demand_strength_nan", "demand_roll_nan", "demand_roll_low", "demand_roll_high",
		"demand_short_block", "demand_missing_roll",
	]:
		var invalid: Dictionary = snapshot.duplicate(true)
		for record: Dictionary in invalid.entities:
			for saved: Dictionary in record.components:
				if String(saved.type) != (C_CustomerFlow as Script).resource_path:
					continue
				var fields: Dictionary = saved.fields as Dictionary
				var cases: Array = fields.parcel_incidents as Array
				var entry: Dictionary = (cases[0] as Dictionary).fields as Dictionary
				if mutation.begins_with("demand_"):
					entry.outcome = REACTIONS.Outcome.KEEP
					entry.demand_outcome = DEMAND.ATTACK
					entry.demand_strength = 5.0
					entry.demand_roll = 0.1
					entry.demand_tick = incident.created_tick
				match mutation:
					"sequence": entry.sequence = 0
					"future": entry.created_tick = incident.created_tick + 1
					"short": entry.next_eligible_tick = incident.created_tick + 1
					"duplicate":
						fields.parcel_incident_sequence = 3
						var duplicate: Dictionary = (cases[0] as Dictionary).duplicate(true)
						(duplicate.fields as Dictionary).sequence = 2
						cases.append(duplicate)
					"missing": entry.erase("created_tick")
					"held":
						entry.phase = CustomerParcelIncident.Phase.HELD
						entry.outcome = CustomerParcelReactionRules.Outcome.KEEP
					"unattempted_strength": entry.demand_strength = 1.0
					"unattempted_roll": entry.demand_roll = 0.5
					"unattempted_tick": entry.demand_tick = incident.created_tick
					"demand_invalid": entry.demand_outcome = DEMAND.INVALID
					"demand_without_keep": entry.outcome = REACTIONS.Outcome.REFUSE
					"demand_future": entry.demand_tick = incident.created_tick + 1
					"demand_before": entry.demand_tick = incident.created_tick - 1
					"demand_wrong_choice": entry.demand_outcome = DEMAND.RETURN
					"demand_strength_nan": entry.demand_strength = NAN
					"demand_roll_nan": entry.demand_roll = NAN
					"demand_roll_low": entry.demand_roll = -0.000001
					"demand_roll_high": entry.demand_roll = 1.000001
					"demand_short_block":
						entry.created_tick -= 1
						entry.next_eligible_tick -= 1
					"demand_missing_roll": entry.erase("demand_roll")
		assert_false(WorldSnapshotService.restore(invalid, _fixture_root), mutation)
		assert_same(flow.parcel_incidents[0], incident)
		assert_eq(_fixture_world.entities.size(), entity_count)


## Exercises every declared Component/record script through the actual codec, including native field
## values.
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
					var first_person: Dictionary = (
						(component.fields.people as Array)[0] as Dictionary
					)
					(first_person.fields as Dictionary).cadence_sample_tick = 123_456_790
		assert_false(WorldSnapshotService.restore(malformed, _fixture_root))
		assert_eq(calendar.clock.elapsed_ticks, 123_456_789)
		assert_eq(calendar.clock.tick_remainder, 0.625)
		assert_eq(NpcPopulationQueries.person_for(_active_id).cadence_sample_tick, 123_456_789)
#endregion
