extends GutTest
## Физическая приёмка машины: маркеры, полная форма, укладка, устойчивые партии и история.

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
	_zone = (load("res://content/entities/zones/receiving_zone.tscn") as PackedScene).instantiate() as E_ReceivingZone
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


## Занятый кузов сохраняет те же ID и сцены; освобождение публикует одно незарегистрированное поступление.
func test_blocked_cargo_preserves_batch_until_space_is_free() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	_plan_big_boxes()
	var ids: PackedStringArray = _state.incoming_package_ids.duplicate()
	var scenes: PackedStringArray = _state.pending[0].package_scenes.duplicate()
	var obstacle: StaticBody3D = _block(Vector3(3, 2, 3), truck.global_position + Vector3(0, 1, 0.75))
	await get_tree().physics_frame
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_true(_state.blocked)
	assert_true(_parcels().is_empty())
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
	assert_eq(record.number, 0)
	assert_eq((_parcels()[0].get_component(C_PackageState) as C_PackageState).registration, C_PackageState.Registration.UNREGISTERED)


## Маркер у стенки не позволяет создать пересекающий её широкий предмет; возврат маркера исправляет размещение.
func test_full_shape_rejects_wall_and_respects_marker_edit() -> void:
	var truck: E_MorningTruck = await _ready_truck()
	_plan_big_boxes()
	var marker: Marker3D = truck.cargo_slots[0]
	truck.cargo_slots.assign([marker])
	marker.position.x = 0.75
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
		_zone, _zone.supply.packages[0], "invalid-scene", 1, 0,
		"res://content/entities/car/car.tscn",
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
	_state.pending[0].package_scenes[0] = "res://content/entities/packages/package_a.tscn"
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
