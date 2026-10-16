extends GutTest
## Физическая приёмка машины: маркеры, полная форма, укладка, устойчивые партии и история.

const NPC_DEFINITIONS_ROOT: String = "res://content/domains/npc/definitions/"


## Reads the committed receiving transaction at its registration publication boundary.
class RegistrationProbe extends Observer:
	## Test-owned callback; never retained outside this fixture's World.
	var callback: Callable


	func query() -> QueryBuilder:
		return q.on_event(PackageScanResult.EVENT)


	func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
		callback.call(entity, payload)


var _root: Node3D
var _world: World
var _zone: E_ReceivingZone
var _state: C_Receiving
var _parking: Marker3D


#region Изолированная реальная приёмка
## Создаёт настоящий кузов, складской журнал и авторскую поставку без симуляции NPC.
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_PackageLedger.new()]
	_world.add_entity(session)
	_zone = (
		(
			load("res://content/domains/packages/entities/receiving_zone.tscn") as PackedScene
		).instantiate()
		as E_ReceivingZone
	)
	_zone.package_parent = _root
	_parking = Marker3D.new()
	_parking.position = Vector3(5, 0, 7)
	_root.add_child(_parking)
	_zone.truck_parking = _parking
	_world.add_entity(_zone)
	_state = _zone.get_component(C_Receiving) as C_Receiving


## Разрывает регистрацию тестовых Entity до удаления общего физического дерева.
func after_each() -> void:
	_world.purge(false)
	_root.queue_free()
	ECS.world = null
	await get_tree().process_frame
	await get_tree().process_frame


func _ready_truck() -> E_MorningTruck:
	var truck: E_MorningTruck = _zone.ensure_truck()
	truck.door_animation.advance(1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return truck


func _plan_big_boxes() -> void:
	var assortment: Array[DEF_Package] = [_zone.supply.packages[1], _zone.supply.packages[2]]
	_zone.supply = _zone.supply.duplicate() as DEF_Delivery
	_zone.supply.packages = assortment
	ReceivingDeliveryService.prepare_batch(_zone.supply, _state, 1)


## Reads the current authored cargo shape, including its offset in the enlarged truck.
func _cargo_shape(truck: E_MorningTruck) -> CollisionShape3D:
	return truck.cargo_area.get_node("CollisionShape3D") as CollisionShape3D


## Computes the actual prefab's compound local bounds without registering or moving a body.
func _big_package_bounds() -> AABB:
	var packed: PackedScene = load(_state.pending[0].package_scenes[0]) as PackedScene
	var body: RigidBody3D = packed.instantiate() as RigidBody3D
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	assert(solver.prepare(body))
	var bounds: AABB = solver.bounds_at(Transform3D.IDENTITY)
	body.free()
	return bounds


func _parcels() -> Array[Entity]:
	return _world.query.with_all([C_Package]).execute()


func _block(size: Vector3, position: Vector3) -> StaticBody3D:
	var obstacle: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	obstacle.add_child(collision)
	_root.add_child(obstacle)
	obstacle.global_position = position
	return obstacle
#endregion


#region Машина и реальные позиции
## Поворот/положение следуют Marker3D, дверь открывается; повтор не создаёт вторую машину.
func test_authored_parking_single_instance_and_existing_door() -> void:
	_parking.rotation.y = PI / 2.0
	var truck: E_MorningTruck = await _ready_truck()
	assert_almost_eq(truck.global_position, _parking.global_position, Vector3.ONE * 0.001)
	assert_true(truck.global_basis.is_equal_approx(_parking.global_basis))
	assert_same(_zone.ensure_truck(), truck)
	assert_eq(truck.cargo_slots.size(), 12)
	assert_same(truck.cargo_area, truck.get_node("SPAWN_ZONE"))
	assert_true((truck.get_node("CollisionShapeDoor") as CollisionShape3D).disabled)
	assert_lt((truck.get_node("Door") as Node3D).scale.y, 0.2)


## Новый экземпляр после фазы использует актуальную авторскую стоянку, а не координаты сервиса.
func test_next_truck_uses_moved_parking() -> void:
	var previous: E_MorningTruck = await _ready_truck()
	_zone.clear_truck()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(previous))
	_parking.position += Vector3(3, 0, -2)
	_parking.rotation.y = -PI / 2.0
	var truck: E_MorningTruck = await _ready_truck()
	assert_true(truck.global_transform.is_equal_approx(_parking.global_transform))


## Занятый кузов не создаёт историю/номер; освобождение регистрирует реальную коробку без сканера.
func test_blocked_cargo_preserves_batch_until_space_is_free() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	_plan_big_boxes()
	var ids: PackedStringArray = _state.incoming_package_ids.duplicate()
	var scenes: PackedStringArray = _state.pending[0].package_scenes.duplicate()
	var cargo_shape: CollisionShape3D = _cargo_shape(truck)
	var volume: AABB = cargo_shape.global_transform * cargo_shape.shape.get_debug_mesh().get_aabb()
	var obstacle: StaticBody3D = _block(volume.size, volume.get_center())
	await get_tree().physics_frame
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_true(_state.blocked)
	assert_true(_parcels().is_empty())
	assert_true(PackageQueries.ledger().records.is_empty())
	for attempt: int in 3:
		ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_eq(_state.incoming_package_ids, ids)
	assert_eq(_state.pending[0].package_scenes, scenes)

	obstacle.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_eq(_parcels().size(), 1)
	var record: PackageRegistrationRecord = PackageHistoryService.record_for(ids[0])
	assert_not_null(record)
	assert_eq(record.number, 1)
	assert_eq(record.received_day, 1)
	assert_eq(record.day_index, 1)
	assert_eq(
		(_parcels()[0].get_component(C_PackageState) as C_PackageState).registration,
		C_PackageState.Registration.REGISTERED,
	)
	assert_eq(
		(_parcels()[0].get_component(C_PackageState) as C_PackageState).scan,
		C_PackageState.Scan.NOT_SCANNED,
	)


## Publication observes committed manifest/state; a recursive delivery cannot duplicate this box.
func test_registration_fact_follows_manifest_and_can_reenter_delivery() -> void:
	await _ready_truck()
	_plan_big_boxes()
	var observed: Dictionary[String, int] = { "events": 0 }
	var probe: RegistrationProbe = RegistrationProbe.new()
	probe.callback = func(parcel: Entity, payload: Variant) -> void:
		var receipt: PackageScanResult = payload as PackageScanResult
		observed.events += 1
		assert_eq(receipt.outcome, PackageScanResult.Outcome.REGISTERED)
		assert_eq(_state.pending[0].next_package, 1)
		assert_eq(_state.delivered_counts[1], 1)
		assert_eq(
			(parcel.get_component(C_PackageState) as C_PackageState).registration_number,
			receipt.number,
		)
		ReceivingDeliveryService.deliver_one(_zone, _state, 1)
		_state.pending.clear()
	_world.add_observer(probe)
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_eq(observed.events, 1)
	assert_eq(_parcels().size(), 1)
	assert_eq(PackageQueries.ledger().records.size(), 1)


## Маркер у стенки не позволяет создать пересекающий её широкий предмет; возврат маркера исправляет
## размещение.
func test_full_shape_rejects_wall_and_respects_marker_edit() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	_plan_big_boxes()
	var marker: Marker3D = truck.cargo_slots[0]
	truck.cargo_slots.assign([marker])
	var cargo_shape: CollisionShape3D = _cargo_shape(truck)
	var volume: AABB = (
		truck.global_transform.affine_inverse() * cargo_shape.global_transform
		* cargo_shape.shape.get_debug_mesh().get_aabb()
	)
	var package_bounds: AABB = _big_package_bounds()
	marker.position.x = volume.end.x - package_bounds.size.x * 0.25
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_true(_state.blocked)
	assert_true(_parcels().is_empty())

	marker.position.x = 0.0
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_eq(_parcels().size(), 1)
	var body: RigidBody3D = _parcels()[0] as Node as RigidBody3D
	assert_almost_eq(body.global_position.x, marker.global_position.x, 0.001)
	assert_almost_eq(body.global_position.z, marker.global_position.z, 0.001)


## Верхний авторский маркер поддерживает коробку первой коробкой, без пересечения и проваливания.
func test_authored_upper_slot_stacks_on_real_box() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	_plan_big_boxes()
	truck.cargo_slots.assign([truck.cargo_slots[0], truck.cargo_slots[6]])
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_eq(_parcels().size(), 1)
	for frame: int in 8:
		await get_tree().physics_frame
	var bottom: RigidBody3D = _parcels()[0] as Node as RigidBody3D
	bottom.freeze = true
	var support_solver: ItemPlacementSolver = ItemPlacementSolver.new()
	assert_true(support_solver.prepare(bottom))
	var support_bounds: AABB = support_solver.bounds_at(bottom.global_transform)
	var local_bounds: AABB = support_solver.bounds_at(Transform3D.IDENTITY)
	var upper: Marker3D = truck.cargo_slots[1]
	# The current authored upper deck is taller than one parcel; edit its fixture height to this
	# real support.
	upper.global_position.y = (
		support_bounds.end.y + truck.placement.clearance - local_bounds.position.y
	)
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_eq(_parcels().size(), 2)
	if _parcels().size() != 2:
		return
	var top: RigidBody3D = _parcels()[1] as Node as RigidBody3D
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	assert_true(solver.prepare(bottom))
	var bottom_bounds: AABB = solver.bounds_at(bottom.global_transform)
	assert_true(solver.prepare(top))
	var top_bounds: AABB = solver.bounds_at(top.global_transform)
	assert_gte(top_bounds.position.y, bottom_bounds.end.y)
	assert_lt(top_bounds.position.y - bottom_bounds.end.y, 0.06)
#endregion


#region Постоянный состав и история
## Planned catalog geometry comes entirely from packing, including recipes without legacy variants.
func test_planned_factory_uses_packing_without_a_legacy_scene_whitelist() -> void:
	var item: DEF_InventoryItem = load(
		"res://content/domains/inventory/definitions/def_item_scythe.tres"
	) as DEF_InventoryItem
	var shipment: PackageShipmentPlan = PackageShipmentRules.for_quantity(
		item, 1, _zone.supply.packing_profiles, 1, "fixture/native_packing", 1,
	)
	var definition: DEF_Package = _zone.supply.packages[0].duplicate() as DEF_Package
	definition.scene_variants = []
	var parcel: E_Package = ReceivingPackageFactory.create(
		_zone, definition, "fixture/native_packing", 1, 0, shipment.scene_path(), shipment,
	)
	assert_not_null(parcel)
	if parcel == null:
		return
	assert_eq(parcel.scene_file_path, shipment.scene_path())
	assert_eq((parcel as Node as RigidBody3D).mass, shipment.gross_mass_kg())
	assert_true(parcel.components.is_empty(), "Factory returns a detached unregistered body")
	parcel.free()


## Blocked truck delivery retains selected contents through restore and catalog changes.
func test_catalog_order_retries_restore_one_real_parcel_with_the_committed_contents() -> void:
	var session: Entity = _world.query.with_all([C_DayCycle]).execute_one()
	var district: C_District = C_District.new()
	district.definition = load(NPC_DEFINITIONS_ROOT + "def_district_default.tres") as DEF_District
	district.people = NpcPopulationRules.initial_records(
		district.definition,
		1,
		DayPhaseQueries.current().clock.world_seed,
	)
	session.add_component(district)
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	flow.schedule = load(
		"res://content/domains/customers/definitions/def_customer_schedule_default.tres"
	) as DEF_CustomerSchedule
	session.add_component(flow)
	var chosen: DEF_InventoryItem = load(
		"res://content/domains/inventory/definitions/def_item_axe.tres"
	) as DEF_InventoryItem
	_zone.supply = _zone.supply.duplicate() as DEF_Delivery
	_zone.supply.packages = [_zone.supply.packages[0]]
	_zone.supply.order_catalog = [chosen]
	var truck: E_MorningTruck = await _ready_truck()
	var slots: Array[Marker3D] = truck.cargo_slots.duplicate()
	truck.cargo_slots.clear()
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_true(_state.blocked)
	assert_true(_parcels().is_empty())
	assert_eq(_state.pending[0].next_package, 0)
	assert_eq(_state.pending[0].order_item_paths[0], chosen.resource_path)
	var captured: Dictionary = SaveDataCodec.component_data(_state).fields as Dictionary
	_zone.supply.order_catalog = [
		load("res://content/domains/inventory/definitions/def_item_holy_artifact.tres")
		as DEF_InventoryItem
	]
	assert_true(SaveDataCodec.apply_fields(_state, captured))
	assert_true(
		ReceivingSnapshotRules.valid(_state, _zone),
		"Committed choice survives catalog changes",
	)
	for paths: PackedStringArray in [
		PackedStringArray(),
		PackedStringArray(["res://project.godot"]),
		PackedStringArray([chosen.resource_path.get_base_dir().path_join("missing_order.tres")]),
	]:
		var invalid: C_Receiving = C_Receiving.new()
		assert_true(SaveDataCodec.apply_fields(invalid, captured))
		invalid.pending[0].order_item_paths = paths
		assert_false(ReceivingSnapshotRules.valid(invalid, _zone))
	truck.cargo_slots.assign(slots)
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_eq(_parcels().size(), 1)
	if _parcels().is_empty():
		return
	var parcel: Entity = _parcels()[0]
	assert_same(
		(parcel.get_component(C_PackageContents) as C_PackageContents).selected_item,
		chosen,
	)
	var contents: C_PackageContents = parcel.get_component(C_PackageContents) as C_PackageContents
	assert_eq(contents.quantity, 1)
	assert_has(contents.packing_profile.scene_variants, parcel.scene_file_path)
	assert_eq((parcel as Node as RigidBody3D).mass, PackageContentsService.full_mass_kg(parcel))
	assert_eq((parcel as Node as RigidBody3D).mass, contents.packing_profile.empty_mass_kg + 2.0)
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	assert_eq(identity.package_id, "base_supply:1:books")
	assert_eq(identity.delivery_day, 1)
	assert_same(identity.definition, _zone.supply.packages[0])
	var record: PackageRegistrationRecord = PackageHistoryService.record_for(identity.package_id)
	assert_same(record.ordered_item, chosen)
	assert_eq(PackageOrderPresentation.title(record), chosen.display_name)
	assert_eq(flow.visits.size(), 1)
	assert_eq(flow.visits[0].package_id, identity.package_id)
	assert_eq(flow.visits[0].customer_id, district.people[0].npc_id)
	assert_true(CustomerFlowQueries.arrival_allowed(flow.visits[0]), "No scanner is required")
	assert_gt(record.number, 0)
	assert_eq(record.day_index, record.received_day)
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_eq(_parcels().size(), 1, "Retry keeps a single real parcel and arrival")
	assert_eq(flow.visits.size(), 1)


## Codec сохраняет состав/физический вариант; уничтожение выданной коробки не создаёт её ещё раз.
func test_restored_batch_and_arrival_history_prevent_duplicate_spawn() -> void:
	await _ready_truck()
	_plan_big_boxes()
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	var original_id: String = _state.incoming_package_ids[0]
	var fields: Dictionary = SaveDataCodec.component_data(_state).fields as Dictionary
	var restored: C_Receiving = C_Receiving.new()
	assert_true(SaveDataCodec.apply_fields(restored, fields))
	assert_eq(restored.batch_id, "base_supply:1")
	assert_eq(restored.incoming_package_ids, _state.incoming_package_ids)
	assert_eq(restored.pending[0].package_scenes, _state.pending[0].package_scenes)
	_world.remove_entity(_parcels()[0])
	await get_tree().physics_frame
	await get_tree().physics_frame

	restored.pending[0].next_package = 0
	ReceivingDeliveryService.deliver_one(_zone, restored, 1)
	assert_eq(restored.pending[0].next_package, 1)
	assert_true(_parcels().is_empty())
	assert_not_null(PackageHistoryService.record_for(original_id))
	ReceivingDeliveryService.prepare_batch(_zone.supply, restored, 1)
	assert_eq(restored.incoming_package_ids, _state.incoming_package_ids)
	ReceivingDeliveryService.prepare_batch(_zone.supply, restored, 2)
	assert_eq(restored.batch_id, "base_supply:2")
	assert_ne(restored.incoming_package_ids, _state.incoming_package_ids)


## Сохранённый физический вариант обязан принадлежать авторскому ассортименту конкретной посылки.
func test_unlisted_saved_scene_is_rejected_without_creating_a_node() -> void:
	var created: E_Package = ReceivingPackageFactory.create(
		_zone,
		_zone.supply.packages[0],
		"invalid-scene",
		1,
		0,
		"res://content/domains/packages/entities/car.tscn",
	)
	assert_null(created)
	assert_true(_parcels().is_empty())
	assert_null(PackageHistoryService.record_for("invalid-scene"))


## Достигнутый лимит ожидающих приостанавливает зафиксированную партию, не выбрасывая остаток.
func test_waiting_capacity_does_not_discard_pending_manifest() -> void:
	await _ready_truck()
	_plan_big_boxes()
	_zone.supply = _zone.supply.duplicate() as DEF_Delivery
	_zone.supply.maximum_waiting_packages = 1
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	var ids: PackedStringArray = _state.incoming_package_ids.duplicate()
	await get_tree().physics_frame
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_true(_state.blocked)
	assert_eq(_state.pending.size(), 1)
	assert_eq(_state.pending[0].next_package, 1)
	assert_eq(_state.incoming_package_ids, ids)

	_world.remove_entity(_parcels()[0])
	await get_tree().physics_frame
	await get_tree().physics_frame
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_eq(_state.pending[0].next_package, 2)
	assert_eq(_parcels().size(), 1)


## Снимок не разделяет packed-массивы ни с живой партией, ни с восстановленными копиями.
func test_snapshot_manifest_and_scene_choices_are_independent() -> void:
	_plan_big_boxes()
	var ids: PackedStringArray = _state.incoming_package_ids.duplicate()
	var scenes: PackedStringArray = _state.pending[0].package_scenes.duplicate()
	var fields: Dictionary = SaveDataCodec.component_data(_state).fields as Dictionary
	_state.incoming_package_ids.clear()
	_state.pending[0].package_scenes[0] = "res://content/domains/packages/entities/package_a.tscn"
	var restored: C_Receiving = C_Receiving.new()
	assert_true(SaveDataCodec.apply_fields(restored, fields))
	assert_eq(restored.incoming_package_ids, ids)
	assert_eq(restored.pending[0].package_scenes, scenes)

	restored.incoming_package_ids.clear()
	restored.pending[0].package_scenes.clear()
	var second_restore: C_Receiving = C_Receiving.new()
	assert_true(SaveDataCodec.apply_fields(second_restore, fields))
	assert_eq(second_restore.incoming_package_ids, ids)
	assert_eq(second_restore.pending[0].package_scenes, scenes)


## Паузы и резервы не переживают restore; постоянный состав партии остаётся прежним.
func test_reset_context_only_clears_transient_placement_state() -> void:
	_plan_big_boxes()
	var ids: PackedStringArray = _state.incoming_package_ids.duplicate()
	_state.blocked = true
	_state.retry_remaining = 4.0
	_state.last_spawn_tick = 5
	_state.reservation_frame = 5
	_state.reservations.append(AABB(Vector3.ZERO, Vector3.ONE))
	ReceivingDeliveryService.reset_context(_state)
	assert_false(_state.blocked)
	assert_eq(_state.retry_remaining, 0.0)
	assert_eq(_state.last_spawn_tick, -1)
	assert_true(_state.reservations.is_empty())
	assert_eq(_state.incoming_package_ids, ids)
#endregion


#region Captured receiving requests
## A queued receiving attempt cannot mutate a replaced Component or create an orphaned historical
## batch.
func test_receiving_manual_flush_rejects_replaced_state() -> void:
	await _ready_truck()
	_plan_big_boxes()
	var owner: S_Receiving = S_Receiving.new()
	owner.group = "ReceivingFixture"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_world.process(0.0, owner.group)
	var previous: C_Receiving = _state
	_zone.remove_component(C_Receiving)
	_zone.add_component(C_Receiving.new())
	_state = _zone.get_component(C_Receiving) as C_Receiving
	_world.flush_command_buffers()
	assert_true(_parcels().is_empty())
	assert_eq(previous.pending[0].next_package, 0)
	assert_eq(_state.last_started_day, 0)

	_world.process(0.0, owner.group)
	_world.flush_command_buffers()
	assert_eq(_parcels().size(), 1)
	assert_eq(_state.last_started_day, 1)


## Changing the phase before a delayed receiving commit prevents a morning spawn in Day.
func test_receiving_manual_flush_revalidates_calendar() -> void:
	await _ready_truck()
	_plan_big_boxes()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var owner: S_Receiving = S_Receiving.new()
	owner.group = "ReceivingFixture"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_world.process(0.0, owner.group)
	cycle.phase = C_DayCycle.Phase.DAY
	_world.flush_command_buffers()
	assert_true(_parcels().is_empty())
	assert_eq(_state.pending[0].next_package, 0)

	cycle.phase = C_DayCycle.Phase.MORNING
	_world.process(0.0, owner.group)
	_world.flush_command_buffers()
	assert_eq(_parcels().size(), 1)
#endregion


#region Retained receiving aggregate reload
## Decoding the same saved manifest invalidates a queued request even when Component/calendar
## identity stays unchanged.
func test_receiving_manual_flush_rejects_redecoded_manifest() -> void:
	await _ready_truck()
	_plan_big_boxes()
	var owner: S_Receiving = S_Receiving.new()
	owner.group = "ReceivingFixture"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_world.process(0.0, owner.group)
	var previous_batch: ReceivingBatch = _state.pending[0]
	var saved: Dictionary = SaveDataCodec.component_data(_state).fields as Dictionary
	assert_true(SaveDataCodec.apply_fields(_state, saved))
	ReceivingDeliveryService.reset_context(_state)
	assert_ne(
		_state.pending[0],
		previous_batch,
		"Typed record state is decoded into the retained Component/Array",
	)
	_world.flush_command_buffers()
	assert_true(_parcels().is_empty())
	assert_eq(_state.pending[0].next_package, 0)

	_world.process(0.0, owner.group)
	_world.flush_command_buffers()
	assert_eq(_parcels().size(), 1)
#endregion
