extends "res://tests/gut/test_trader_purchase.gd"
## Приёмка площадки, полной формы, ограниченных утренних повторов и постоянного результата доставки.

#region Площадка и оплаченные заказы
func _area(zone: Entity, position: Vector3 = Vector3(-8, 0.22, 8)) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	marker.position = position
	_root.add_child(marker)
	var state: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	state.furniture_anchor_path = zone.get_path_to(marker)
	state.furniture_placement = state.furniture_placement.duplicate() as DEF_ItemPlacement
	state.furniture_placement.offsets = PackedVector3Array([Vector3.ZERO])
	return marker

func _paid(operation_id: StringName = &"arrival") -> PendingDelivery:
	assert_eq(CommerceService.home_delivery(_actor, _trader, _shelf, 1, operation_id), CommerceService.Status.COMMITTED)
	return _commerce.pending_deliveries.back()

func _receiving_system() -> S_OrderDelivery:
	var system: S_OrderDelivery = S_OrderDelivery.new()
	system.group = "TestArrival"
	_world.add_system(system, true)
	return system
#endregion

#region Авторский маркер и физическое исполнение
## Форма, которую solver не умеет разместить, отклоняется до оплаты заказа.
func test_unsupported_physical_shape_is_rejected_before_payment() -> void:
	var invalid: DEF_InventoryItem = _shelf.duplicate() as DEF_InventoryItem
	invalid.world_pickup_scene = "res://tests/fixtures/unsupported_delivery_furniture.tscn"
	var profile: DEF_TraderProfile = _shop.profile.duplicate() as DEF_TraderProfile
	profile.catalog = [invalid]
	_shop.profile = profile
	var legacy_probe: Entity = FurniturePlacement.create_validated(invalid)
	assert_not_null(legacy_probe, "Fixture has valid bounds; unsupported shape is rejected by the shared solver")
	if legacy_probe != null:
		legacy_probe.free()
	assert_false(OrderDeliveryService.can_fulfill_definition(invalid))
	assert_eq(CommerceService.home_delivery(_actor, _trader, invalid, 1, &"unsupported"), CommerceService.Status.INVALID)
	assert_eq(_wallet.balance, 1000)
	assert_true(_wallet.operations.is_empty())
	assert_true(_commerce.receipts.is_empty())
	assert_true(_commerce.pending_deliveries.is_empty())


## Поворот/перемещение маркера меняет выдачу; после создания мебель не следует за маркером.
func test_marker_pose_controls_delivery_and_preserves_uninstalled_physical_furniture() -> void:
	var order: PendingDelivery = _paid()
	var zone: Entity = _home()
	var marker: Marker3D = _area(zone)
	marker.rotation.y = PI / 2.0
	var state: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	state.furniture_placement.offsets = PackedVector3Array([Vector3(3.5, 0, 0)])
	assert_false(OrderDeliveryService.fulfill_one(zone, state, _commerce, 1))
	assert_false(order.fulfilled)
	assert_true(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))
	var goods: Entity = _goods(OrderDeliveryService.key_for(order))
	assert_not_null(goods)
	var body: RigidBody3D = goods as Node as RigidBody3D
	var expected: Vector3 = marker.to_global(Vector3(3.5, 0, 0))
	assert_almost_eq(body.global_position.x, expected.x, 0.001)
	assert_almost_eq(body.global_position.z, expected.z, 0.001)
	assert_almost_eq(body.global_position.y, 1.55, 0.001)
	assert_true(body.global_basis.is_equal_approx(marker.global_basis))
	assert_same(body.get_parent(), _root)
	assert_eq(goods.id, OrderDeliveryService.key_for(order))
	assert_true(goods.has_component(C_Grabbable))
	assert_true(goods.has_component(C_Anchorable))
	assert_false(goods.has_component(C_PlayerAnchored))
	assert_false(body.freeze)
	var pose: Transform3D = body.global_transform
	marker.position += Vector3.RIGHT
	assert_eq(body.global_transform, pose)
	assert_eq(_wallet.balance, 720)
	assert_false(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))

## Пропавшая ссылка и опора только под центром не создают мебель или ложное исполнение.
func test_missing_marker_and_partial_support_leave_paid_order_waiting() -> void:
	var order: PendingDelivery = _paid()
	var zone: Entity = _home()
	var marker: Marker3D = _area(zone)
	var state: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	state.furniture_anchor_path = NodePath("Missing")
	assert_false(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))
	assert_true(state.blocked)
	state.furniture_anchor_path = zone.get_path_to(marker)
	_floor.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_block(Vector3(-8, -0.1, 8), Vector3(1, 0.2, 1))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))
	assert_false(order.fulfilled)
	assert_null(_goods(OrderDeliveryService.key_for(order)))
	assert_eq(_wallet.balance, 720)
	_floor = _block(Vector3(0, -0.1, 0), Vector3(40, 0.2, 40))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))

## Резервы предотвращают пересечение двух выдач до обновления физики и после него.
func test_same_frame_and_later_orders_use_separate_safe_positions() -> void:
	var first: PendingDelivery = _paid(&"first")
	var second: PendingDelivery = _paid(&"second")
	var zone: Entity = _home()
	_area(zone)
	var state: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	state.furniture_placement.offsets = PackedVector3Array([Vector3.ZERO, Vector3(3.5, 0, 0)])
	assert_true(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))
	assert_true(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))
	assert_false(state.reservations[0].intersects(state.reservations[1]))
	assert_true(first.fulfilled and second.fulfilled)
	assert_eq(_world.query.with_all([C_Anchorable]).execute().size(), 2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_wallet.balance = 1000
	var third: PendingDelivery = _paid(&"third")
	state.furniture_placement.offsets = PackedVector3Array([Vector3.ZERO, Vector3(3.5, 0, 0), Vector3(0, 0, 2.5)])
	assert_true(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))
	assert_true(third.fulfilled)
	assert_eq(_world.query.with_all([C_Anchorable]).execute().size(), 3)
#endregion

#region Ограниченный повтор и восстановление
## Заблокированная выдача ждёт паузу, выполняется только утром и не повторяет оплату.
func test_system_waits_for_retry_interval_and_next_morning_without_repayment() -> void:
	var order: PendingDelivery = _paid()
	var zone: Entity = _home()
	_area(zone)
	var state: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	_receiving_system()
	var blocker: StaticBody3D = _block(Vector3(-8, 1.5, 8), Vector3(5, 4, 5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_cycle.day_index = 2
	_cycle.phase = C_DayCycle.Phase.MORNING
	_world.process(0.01, "TestArrival")
	assert_true(state.blocked)
	assert_false(order.fulfilled)
	assert_eq(state.retry_remaining, state.retry_seconds)
	blocker.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_world.process(state.retry_seconds * 0.5, "TestArrival")
	assert_false(order.fulfilled)
	_cycle.phase = C_DayCycle.Phase.DAY
	_world.process(state.retry_seconds, "TestArrival")
	assert_false(order.fulfilled)
	_cycle.phase = C_DayCycle.Phase.MORNING
	_world.process(state.retry_seconds, "TestArrival")
	assert_true(order.fulfilled)
	assert_eq(_wallet.balance, 720)
	assert_eq(_wallet.operations.size(), 1)
	_world.process(state.retry_seconds, "TestArrival")
	assert_true(state.exhausted)
	_cycle.phase = C_DayCycle.Phase.MORNING
	_cycle.day_index = 3
	_world.process(0.01, "TestArrival")
	assert_eq(_world.query.with_all([C_Anchorable]).execute().size(), 1)

## Занятость переживает снимок; восстановление сбрасывает кеши и выдаёт оплаченный остаток один раз.
func test_full_snapshot_restores_blocked_order_then_issued_item_without_duplication() -> void:
	var order: PendingDelivery = _paid()
	var zone: Entity = _home()
	zone.name = "Receiving"
	zone.owner = _root
	_area(zone)
	var state: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	var blocker: StaticBody3D = _block(Vector3(-8, 1.5, 8), Vector3(5, 4, 5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))
	state.retry_remaining = 100.0
	state.reservations = [AABB(Vector3.ZERO, Vector3.ONE)]
	state.reservation_frame = Engine.get_physics_frames()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(state.retry_remaining, 0.0)
	assert_true(state.reservations.is_empty())
	assert_false(state.identity_index_ready)
	assert_false(_commerce.pending_deliveries[0].fulfilled)
	blocker.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))
	var key: String = OrderDeliveryService.key_for(_commerce.pending_deliveries[0])
	assert_not_null(_goods(key))
	var issued: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.restore(issued, _root))
	assert_true(WorldSnapshotService.restore(issued, _root))
	assert_false(OrderDeliveryService.fulfill_one(zone, state, _commerce, 2))
	assert_eq(_world.query.with_all([C_Anchorable]).execute().size(), 1)
	assert_eq(_wallet.balance, 720)
	assert_eq(_wallet.operations.size(), 1)
	_world.remove_entity(_goods(key))
	assert_false(OrderDeliveryService.fulfill_one(zone, state, _commerce, 3), "Fulfilled orders do not resurrect removed furniture")
#endregion

#region Deferred paid-order lifetime
## An already paid order stays pending if its queued morning placement crosses a phase change.
func test_order_manual_flush_revalidates_calendar_without_repayment() -> void:
	var order: PendingDelivery = _paid()
	var zone: Entity = _home()
	_area(zone)
	var owner: S_OrderDelivery = _receiving_system()
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_cycle.day_index = 2
	_cycle.phase = C_DayCycle.Phase.MORNING
	_world.process(0.01, "TestArrival")
	_cycle.phase = C_DayCycle.Phase.DAY
	_world.flush_command_buffers()
	assert_false(order.fulfilled)
	assert_null(_goods(OrderDeliveryService.key_for(order)))
	assert_eq(_wallet.balance, 720)

	_cycle.phase = C_DayCycle.Phase.MORNING
	_world.process(1.0, "TestArrival")
	_world.flush_command_buffers()
	assert_true(order.fulfilled)
	assert_eq(_wallet.operations.size(), 1)


## A replaced receiving Component cannot be fulfilled through its pre-load queued command.
func test_order_manual_flush_rejects_replaced_receiving_component() -> void:
	var order: PendingDelivery = _paid()
	var zone: Entity = _home()
	_area(zone)
	var original: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	var owner: S_OrderDelivery = _receiving_system()
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_cycle.day_index = 2
	_cycle.phase = C_DayCycle.Phase.MORNING
	_world.process(0.01, "TestArrival")

	zone.remove_component(C_OrderReceiving)
	var replacement: C_OrderReceiving = C_OrderReceiving.new()
	replacement.furniture_anchor_path = original.furniture_anchor_path
	replacement.furniture_placement = original.furniture_placement
	zone.add_component(replacement)
	_world.flush_command_buffers()
	assert_false(order.fulfilled)
	assert_null(_goods(OrderDeliveryService.key_for(order)))

	_world.process(0.01, "TestArrival")
	_world.flush_command_buffers()
	assert_true(order.fulfilled)
	assert_eq(_wallet.operations.size(), 1)
#endregion

#region Same-morning paid-order restore
## Restore invalidates a queued fulfillment even when the authored receiving/calendar/commerce Components survive.
func test_order_manual_flush_discards_same_morning_preload_ticket() -> void:
	var order: PendingDelivery = _paid()
	var delivery_key: String = OrderDeliveryService.key_for(order)
	var zone: Entity = _home()
	zone.name = "Receiving"
	zone.owner = _root
	_area(zone)
	var state: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	var owner: S_OrderDelivery = _receiving_system()
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_cycle.day_index = 2
	_cycle.phase = C_DayCycle.Phase.MORNING
	_world.process(0.01, "TestArrival")
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(zone.get_component(C_OrderReceiving), state)
	assert_false(state.delivery_queued)
	_world.flush_command_buffers()
	assert_false(_commerce.pending_deliveries[0].fulfilled)
	assert_null(_goods(delivery_key))
	assert_eq(state.retry_remaining, 0.0)

	_world.process(0.01, "TestArrival")
	_world.flush_command_buffers()
	assert_true(_commerce.pending_deliveries[0].fulfilled)
	assert_not_null(_goods(delivery_key))
	assert_eq(_wallet.operations.size(), 1)
#endregion
