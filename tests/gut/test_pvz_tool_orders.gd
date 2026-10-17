extends "res://tests/gut/test_hag_direct_shop.gd"
## Own PVZ catalog, actual terminal entry and native once-only tool delivery/restore.

const PVZ_SCANNER: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_scanner.tres"
)
const PVZ_MARKER: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_marker.tres"
)
const PVZ_ZONE: PackedScene = preload(
	"res://content/domains/commerce/entities/order_receiving.tscn"
)


#region Real terminal delivery fixture
func _tool_zone() -> Entity:
	var zone: Entity = PVZ_ZONE.instantiate() as Entity
	(zone as Node as Node3D).position = Vector3(-40, 0.22, 0)
	EntityCompositionFixture.register(_world, zone)
	var owner: S_OrderDelivery = S_OrderDelivery.new()
	owner.group = "TestPvzTools"
	_world.add_system(owner)
	_money.balance = 1000
	DayPhaseQueries.current().phase = C_DayCycle.Phase.MORNING
	return zone


func _tick_tools() -> void:
	_world.process(2.0, "TestPvzTools")
	_world.flush_command_buffers()
	await get_tree().physics_frame
#endregion


#region Catalog and explicit native UI
func test_pvz_native_terminal_shows_its_own_tools_day_price_and_place_before_payment() -> void:
	_tool_zone()
	var catalog: Array[DEF_InventoryItem] = CommerceService.current().catalog
	assert_eq(
		catalog.map(
			func(item: DEF_InventoryItem) -> StringName:
				return item.key,
		),
		[&"bubble_wrap", &"scanner", &"marker"],
	)
	assert_false(PVZ_SCANNER in HAG_PROFILE.catalog)
	assert_false(PVZ_MARKER in HAG_PROFILE.catalog)
	assert_eq(
		PVZ_SCANNER.world_pickup_scene,
		"res://content/domains/packages/entities/scanner.tscn",
	)
	assert_eq(
		PVZ_MARKER.world_pickup_scene,
		"res://content/domains/interaction/entities/marker.tscn",
	)
	var terminal: E_Terminal = (
		load("res://content/domains/packages/entities/terminal.tscn") as PackedScene
	).instantiate() as E_Terminal
	EntityCompositionFixture.register(_world, terminal)
	terminal.open_for(_seller)
	assert_true(terminal.is_open_for(_seller))
	var journal: TerminalPanel = terminal.get_node("TerminalPanel") as TerminalPanel
	var entry: Button = journal.get_node("%ButtonOrders") as Button
	assert_eq(entry.text, "Снабжение ПВЗ")
	entry.pressed.emit()
	assert_false(terminal.is_panel_open())
	var panel: CommercePanel = _seller.find_child("CommercePanel", false, false) as CommercePanel
	assert_not_null(panel)
	if panel == null:
		return
	var root: String = "Root/Center/Panel/Content/"
	assert_true((panel.get_node(root + "Title") as Label).text.contains("ПВЗ"))
	assert_true((panel.get_node(root + "Status") as Label).text.contains("площадка"))
	var offers: VBoxContainer = panel.get_node(root + "OffersScroll/Offers") as VBoxContainer
	assert_eq(offers.get_child_count(), 3)
	for index: int in catalog.size():
		var button: Button = offers.get_child(index).get_child(0) as Button
		assert_true(button.text.contains(catalog[index].display_name))
		assert_true(button.text.contains(str(catalog[index].market_price)))
		assert_true(button.text.contains("×1"))
		assert_true(button.tooltip_text.contains("Утро дня 2"))
		assert_true(button.tooltip_text.contains("Площадка"))
		assert_false(button.disabled, "PVZ ordering is open in Morning independently of Hag")
	assert_false((panel.get_node(root + "BuybackButton") as Button).visible)
	assert_eq(_money.balance, 1000)
	assert_true(_money.operations.is_empty())
	panel.close_panel()
	await get_tree().process_frame
	assert_lt(InteractionControlFocus.current(_seller), InteractionControlFocus.Priority.MODAL)


func test_unsupported_order_prefab_refuses_before_money_receipt_and_queue() -> void:
	_tool_zone()
	var unsupported: DEF_InventoryItem = PVZ_SCANNER.duplicate() as DEF_InventoryItem
	unsupported.key = &"unsupported_tool"
	CommerceService.current().catalog = [unsupported]
	for scene: String in ["", "res://content/domains/commerce/entities/order_receiving.tscn"]:
		unsupported.world_pickup_scene = scene
		assert_eq(
			CommerceService.order(_seller, unsupported, 1, &"pvz/unsupported"),
			CommerceService.Status.INVALID,
		)
	assert_eq(_money.balance, 1000)
	assert_true(_money.operations.is_empty())
	assert_true(CommerceService.current().receipts.is_empty())
	assert_true(CommerceService.current().pending_deliveries.is_empty())
	assert_false(CommerceService.current().transaction_in_progress)
#endregion


#region Actual scheduled native goods and persistence
func test_scanner_and_marker_orders_restore_then_issue_once_in_the_existing_pvz_zone() -> void:
	var zone: Entity = _tool_zone()
	var zone_id: String = zone.id
	for definition: DEF_InventoryItem in [PVZ_SCANNER, PVZ_MARKER]:
		assert_eq(
			CommerceService.order(_seller, definition, 1, definition.key),
			CommerceService.Status.COMMITTED,
		)
	assert_eq(_money.balance, 1000 - PVZ_SCANNER.market_price - PVZ_MARKER.market_price)
	assert_eq(_money.operations.size(), 2)
	await _tick_tools()
	for delivery: PendingDelivery in CommerceService.current().pending_deliveries:
		assert_false(delivery.fulfilled)
		assert_false(_world.entity_id_registry.has(OrderDeliveryService.key_for(delivery)))
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_not_null(_world.entity_id_registry.get(zone_id))
	_morning(2)
	await _tick_tools()
	await _tick_tools()
	var scanner_id: String = "order/scanner"
	var marker_id: String = "order/marker"
	var scanner: Entity = _world.entity_id_registry.get(scanner_id) as Entity
	var marker: Entity = _world.entity_id_registry.get(marker_id) as Entity
	assert_not_null(scanner)
	assert_not_null(marker)
	if scanner == null or marker == null:
		return
	assert_true((scanner as Node) is RigidBody3D)
	assert_true((marker as Node) is RigidBody3D)
	assert_true(scanner is E_Scanner)
	assert_eq((scanner.get_component(C_Scanner) as C_Scanner).scan_range, 3.0)
	assert_eq((marker.get_component(C_Marker) as C_Marker).drawing_range, 5.0)
	assert_true(scanner.has_component(C_Grabbable))
	assert_true(marker.has_component(C_Grabbable))
	assert_null(scanner.get_component(C_InventoryItem))
	assert_null(marker.get_component(C_InventoryItem))
	assert_eq(
		(scanner.get_component(C_InteractionActionSet) as C_InteractionActionSet)
		.actions[0]
		.action_id,
		&"scan_package",
	)
	assert_eq(
		(marker.get_component(C_InteractionActionSet) as C_InteractionActionSet)
		.actions[0]
		.action_id,
		&"mark_package",
	)
	(scanner as Node as Node3D).global_position = Vector3(-25, 1, 0)
	_world.remove_entity(marker)
	_world.flush_command_buffers()
	snapshot = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	await _tick_tools()
	assert_false(_world.entity_id_registry.has(marker_id), "Consumed issued tool cannot reappear")
	assert_almost_eq(
		(_world.entity_id_registry.get(scanner_id) as Node3D).global_position.x,
		-25.0,
		0.01,
	)
	for delivery: PendingDelivery in CommerceService.current().pending_deliveries:
		assert_true(delivery.fulfilled)
		assert_eq(
			CommerceService.order(_seller, delivery.item, 1, delivery.delivery_id),
			CommerceService.Status.DUPLICATE,
		)
	assert_eq(_money.operations.size(), 2)


func test_blocked_tool_debt_survives_restore_and_retries_without_another_payment() -> void:
	var zone: Entity = _tool_zone()
	assert_eq(
		CommerceService.order(_seller, PVZ_SCANNER, 1, &"pvz/blocked"),
		CommerceService.Status.COMMITTED,
	)
	var blocker: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(14, 8, 12)
	collision.shape = shape
	blocker.add_child(collision)
	blocker.position = Vector3(-40, 4, 0)
	_root.add_child(blocker)
	_morning(2)
	await _physics_settled()
	await _tick_tools()
	assert_false(CommerceService.current().pending_deliveries[0].fulfilled)
	assert_true((zone.get_component(C_OrderReceiving) as C_OrderReceiving).blocked)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_false(_world.entity_id_registry.has("order/pvz/blocked"))
	blocker.free()
	await _physics_settled()
	await _tick_tools()
	assert_true(CommerceService.current().pending_deliveries[0].fulfilled)
	assert_not_null(_world.entity_id_registry.get("order/pvz/blocked"))
	assert_eq(_money.operations.size(), 1)
	assert_eq(_money.balance, 1000 - PVZ_SCANNER.market_price)
#endregion


#region Existing paid PVZ promises
func test_old_paid_food_order_keeps_its_pvz_owner_after_the_new_tool_catalog() -> void:
	_tool_zone()
	var commerce: C_Commerce = CommerceService.current()
	var production_catalog: Array[DEF_InventoryItem] = commerce.catalog
	var food: DEF_InventoryItem = load(
		"res://content/domains/inventory/definitions/def_item_food.tres",
	) as DEF_InventoryItem
	commerce.catalog = [food]
	assert_eq(
		CommerceService.order(_seller, food, 2, &"pvz/old-food"),
		CommerceService.Status.COMMITTED,
	)
	commerce.catalog = production_catalog
	assert_false(food in commerce.catalog)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_false(food in CommerceService.current().catalog)
	var delivery: PendingDelivery = CommerceService.current().pending_deliveries[0]
	assert_same(delivery.item, food)
	assert_eq(delivery.quantity, 2)
	_morning(2)
	await _tick_tools()
	assert_true(delivery.fulfilled)
	var goods: Entity = _world.entity_id_registry.get("order/pvz/old-food") as Entity
	assert_not_null(goods)
	if goods == null:
		return
	var stack: C_InventoryItem = goods.get_component(C_InventoryItem) as C_InventoryItem
	assert_same(stack.definition, food)
	assert_eq(stack.quantity, 2)
	await _tick_tools()
	assert_same(_world.entity_id_registry.get("order/pvz/old-food"), goods)
	assert_eq(_money.operations.size(), 1)
	assert_eq(_money.balance, 1000 - food.market_price * 2)
#endregion
