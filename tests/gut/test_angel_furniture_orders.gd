extends GutTest
## Реальные независимые terminal/UI/physics/restore контракты Ангела и прежнего ПВЗ.

const ANGEL: PackedScene = preload(
	"res://content/domains/commerce/entities/angel_furniture_terminal.tscn"
)
const PVZ_ZONE: PackedScene = preload(
	"res://content/domains/commerce/entities/order_receiving.tscn"
)
var _shelf: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_large_shelf.tres"
)
const FOOD: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_food.tres"
)
const SAVE_PATH: String = "user://gut_angel_furniture_orders.pvzh"

var _root: Node3D
var _world: World
var _session: Entity
var _actor: Entity
var _terminal: E_Terminal
var _state: C_AngelOrders
var _cycle: C_DayCycle
var _wallet: C_Wallet
var _commerce: C_Commerce
var _profile: DEF_AngelFurnitureShop
var _catalog: Array[DEF_InventoryItem]
var _hint: String
var _old_price: int


#region Minimal real native fixture
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	_session = Entity.new()
	_session.component_resources = [C_DayCycle.new(), C_Wallet.new(), C_Commerce.new()]
	_placed(_session, &"session")
	_cycle = DayPhaseQueries.current()
	_wallet = WalletService.current()
	_wallet.balance = 2000
	_commerce = CommerceService.current()
	_actor = Entity.new()
	_actor.component_resources = [C_Inventory.new(), C_GrabControl.new()]
	_placed(_actor, &"player")
	_terminal = ANGEL.instantiate() as E_Terminal
	(_terminal as Node as Node3D).position = Vector3(9, 0, 0)
	_placed(_terminal, &"angel_terminal")
	_state = _terminal.get_component(C_AngelOrders) as C_AngelOrders
	_profile = _state.profile
	_catalog = _profile.catalog.duplicate()
	_hint = _profile.receiving_hint
	_old_price = _shelf.market_price
	_block(Vector3(0, -0.1, 0), Vector3(70, 0.2, 70))
	var delivery: S_AngelOrderDelivery = S_AngelOrderDelivery.new()
	delivery.group = "TestAngel"
	_world.add_system(delivery)
	var pvz: S_OrderDelivery = S_OrderDelivery.new()
	pvz.group = "TestAngel"
	_world.add_system(pvz)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	if is_instance_valid(_terminal):
		_terminal.close_panel()
	_profile.catalog = _catalog
	_profile.receiving_hint = _hint
	_shelf.market_price = _old_price
	_world.purge(false)
	_root.free()
	ECS.world = null
	await get_tree().process_frame
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _placed(entity: Entity, role: StringName) -> void:
	_root.add_child(entity)
	entity.owner = _root
	FixturePlacedIdentity.assign(_root, entity, role)
	EntityCompositionFixture.register(_world, entity, false)


func _block(position: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = position
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_root.add_child(body)
	return body


func _tick(delta: float = 2.0) -> void:
	_world.process(delta, "TestAngel")
	_world.flush_command_buffers()
	await get_tree().physics_frame


func _order() -> AngelFurnitureQuote:
	var offer: AngelFurnitureQuote = AngelFurnitureService.quote(_actor, _terminal, _shelf)
	assert_eq(offer.reason, "")
	assert_eq(AngelFurnitureService.confirm(_actor, offer), AngelFurnitureService.Status.COMMITTED)
	return offer


func _restore(snapshot: Dictionary) -> void:
	assert_false(snapshot.is_empty())
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	_state = _terminal.get_component(C_AngelOrders) as C_AngelOrders
	_cycle = DayPhaseQueries.current()
	_wallet = WalletService.current()
	_commerce = CommerceService.current()


func _pvz() -> Entity:
	var zone: Entity = PVZ_ZONE.instantiate() as Entity
	(zone as Node as Node3D).position = Vector3(-12, 0.22, -5)
	_placed(zone, &"pvz_receiving")
	return zone
#endregion


#region Native UI and prepayment
func test_native_action_own_ui_confirmation_cancel_and_focus_without_pvz_terminal() -> void:
	var action: DEF_InteractionAction = (
		_terminal.get_component(C_InteractionActionSet) as C_InteractionActionSet
	).actions[0]
	assert_true(action.is_available(_actor, _terminal, null))
	action.execute(_actor, _terminal, null)
	assert_true(_terminal.is_open_for(_actor))
	var ui: AngelFurniturePanel = _terminal.get_node("AngelFurniturePanel") as AngelFurniturePanel
	var buttons: Node = ui.get_node("Shop/Contents/CatalogScroll/Catalog")
	var button: Button = buttons.get_child(0) as Button
	assert_string_contains(button.text, "×1")
	assert_string_contains(button.text, str(_shelf.market_price))
	assert_string_contains(button.tooltip_text, "дня 2")
	assert_string_contains(button.tooltip_text, _hint)
	button.pressed.emit()
	var confirmation: ConfirmationDialog = ui.get_node("Confirmation") as ConfirmationDialog
	assert_true(confirmation.visible)
	assert_string_contains(confirmation.dialog_text, str(_shelf.market_price))
	assert_string_contains(confirmation.dialog_text, _hint)
	assert_true(_wallet.operations.is_empty())
	confirmation.canceled.emit()
	confirmation.hide()
	_terminal.close_panel()
	assert_false(_terminal.is_panel_open())
	assert_eq(InteractionControlFocus.current(_actor), 0)
	assert_true(_state.orders.is_empty())
	action.execute(_actor, _terminal, null)
	button = ui.get_node("Shop/Contents/CatalogScroll/Catalog").get_child(0) as Button
	button.pressed.emit()
	confirmation.confirmed.emit()
	assert_eq(_state.orders.size(), 1)
	assert_eq(_wallet.operations.size(), 1)
	assert_true(_commerce.pending_deliveries.is_empty())
	assert_true(_commerce.receipts.is_empty())
	assert_string_contains((ui.get_node("Shop/Contents/History") as RichTextLabel).text, "оплачено")
	var back: InputEventAction = InputEventAction.new()
	back.action = &"menu"
	back.pressed = true
	(ui.get_node("Shop") as Window).window_input.emit(back)
	assert_false(_terminal.is_panel_open())
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)


func test_old_confirmation_rechecks_price_phase_money_and_current_native_placement() -> void:
	var offer: AngelFurnitureQuote = AngelFurnitureService.quote(_actor, _terminal, _shelf)
	_shelf.market_price += 1
	assert_eq(AngelFurnitureService.confirm(_actor, offer), AngelFurnitureService.Status.CHANGED)
	_shelf.market_price = _old_price
	_cycle.phase = C_DayCycle.Phase.NIGHT
	assert_eq(
		AngelFurnitureService.confirm(_actor, offer),
		AngelFurnitureService.Status.UNAVAILABLE,
	)
	_cycle.phase = C_DayCycle.Phase.MORNING
	_wallet.balance = 0
	assert_eq(
		AngelFurnitureService.confirm(_actor, offer),
		AngelFurnitureService.Status.INSUFFICIENT_FUNDS,
	)
	_wallet.balance = 2000
	var block: StaticBody3D = _block(Vector3(9, 3, -5), Vector3(18, 6, 15))
	await get_tree().physics_frame
	assert_eq(
		AngelFurnitureService.confirm(_actor, offer),
		AngelFurnitureService.Status.UNAVAILABLE,
	)
	assert_eq(_wallet.balance, 2000)
	assert_true(_wallet.operations.is_empty())
	assert_true(_state.orders.is_empty())
	block.queue_free()


func test_wrong_definition_and_missing_receiving_marker_refuse_without_payment() -> void:
	for item: DEF_InventoryItem in [FOOD, null]:
		assert_false(AngelFurnitureService.quote(_actor, _terminal, item).reason.is_empty())
	var receiving: C_OrderReceiving = _terminal.get_component(C_OrderReceiving) as C_OrderReceiving
	receiving.furniture_anchor_path = NodePath("Missing")
	assert_false(AngelFurnitureService.quote(_actor, _terminal, _shelf).reason.is_empty())
	assert_eq(_wallet.balance, 2000)
	assert_true(_wallet.operations.is_empty())
	assert_true(_state.orders.is_empty())


func test_unsavable_inline_catalog_and_incompatible_native_prefab_refuse_before_payment() -> void:
	var inline_item: DEF_InventoryItem = _shelf.duplicate() as DEF_InventoryItem
	_profile.catalog = [inline_item]
	assert_false(AngelFurnitureService.quote(_actor, _terminal, inline_item).reason.is_empty())
	_profile.catalog = _catalog
	var original_scene: String = _shelf.world_pickup_scene
	_shelf.world_pickup_scene = "res://content/domains/commerce/entities/order_receiving.tscn"
	var offer: AngelFurnitureQuote = AngelFurnitureService.quote(_actor, _terminal, _shelf)
	_shelf.world_pickup_scene = original_scene
	assert_false(offer.reason.is_empty())
	assert_eq(_wallet.balance, 2000)
	assert_true(_wallet.operations.is_empty())
	assert_true(_state.orders.is_empty())
#endregion


#region Independent owners and once-only native delivery
func test_angel_opens_pays_restores_and_fulfills_without_pvz_commerce_owner() -> void:
	_session.remove_component(C_Commerce)
	assert_null(CommerceService.current())
	_terminal.open_for(_actor)
	assert_true(_terminal.is_open_for(_actor))
	_terminal.close_panel()
	var offer: AngelFurnitureQuote = _order()
	assert_eq(AngelFurnitureService.confirm(_actor, offer), AngelFurnitureService.Status.DUPLICATE)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	_restore(AutosaveStore.read(SAVE_PATH))
	assert_null(CommerceService.current())
	await _tick()
	assert_false(_state.orders[0].issued)
	_cycle.day_index = 2
	await _tick()
	var record: AngelFurnitureOrder = _state.orders[0]
	assert_true(record.issued)
	var goods: Entity = _world.get_entity_by_id(record.output_id)
	assert_not_null(goods)
	assert_true((goods as Node) is RigidBody3D)
	assert_false((goods as Node as RigidBody3D).freeze)
	assert_false(goods.has_component(C_PlayerAnchored))
	assert_same(goods.get_parent(), _root)
	var issued_pose: Transform3D = (goods as Node as Node3D).global_transform
	(_terminal as Node as Node3D).global_position += Vector3(3, 0, 0)
	assert_eq((goods as Node as Node3D).global_transform, issued_pose)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_wallet.balance, 2000 - _old_price)


func test_pvz_opens_pays_and_fulfills_with_angel_terminal_absent() -> void:
	_world.remove_entity(_terminal)
	await get_tree().process_frame
	_pvz()
	var pvz: E_Terminal = (
		load("res://content/domains/packages/entities/terminal.tscn") as PackedScene
	).instantiate() as E_Terminal
	_placed(pvz, &"pvz_terminal")
	pvz.open_for(_actor)
	assert_true(pvz.is_open_for(_actor))
	pvz.close_panel()
	assert_eq(
		CommerceService.order(_actor, FOOD, 1, &"pvz/without_angel"),
		CommerceService.Status.COMMITTED,
	)
	_cycle.day_index = 2
	await _tick()
	assert_true(_commerce.pending_deliveries[0].fulfilled)
	assert_not_null(_world.get_entity_by_id("order/pvz/without_angel"))
	assert_eq(_commerce.receipts.size(), 1)
	assert_eq(_wallet.operations.size(), 1)


func test_blocked_angel_debt_and_retry_do_not_mutate_pvz_place_history_or_queue() -> void:
	var pvz: Entity = _pvz()
	_order()
	assert_eq(
		CommerceService.order(_actor, FOOD, 1, &"pvz/separate"),
		CommerceService.Status.COMMITTED,
	)
	var block: StaticBody3D = _block(Vector3(9, 3, -5), Vector3(18, 6, 15))
	await get_tree().physics_frame
	_cycle.day_index = 2
	await _tick()
	assert_false(_state.orders[0].issued)
	assert_true((_terminal.get_component(C_OrderReceiving) as C_OrderReceiving).blocked)
	assert_true(_commerce.pending_deliveries[0].fulfilled)
	assert_false((pvz.get_component(C_OrderReceiving) as C_OrderReceiving).blocked)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_restore(snapshot)
	block.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _tick()
	assert_true(_state.orders[0].issued)
	assert_eq(_commerce.pending_deliveries.size(), 1)
	assert_eq(_commerce.receipts.size(), 1)
	assert_eq(_wallet.operations.size(), 2)
	assert_not_null(_world.get_entity_by_id("order/pvz/separate"))


func test_multiple_frozen_promises_restore_issue_then_moved_deleted_goods_never_repeat() -> void:
	_order()
	_order()
	assert_eq(_state.orders.size(), 2)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	_profile.catalog = []
	_profile.receiving_hint = "Новая подсказка только для новых заказов"
	_shelf.market_price = 999
	_restore(AutosaveStore.read(SAVE_PATH))
	assert_false(AngelFurnitureService.quote(_actor, _terminal, _shelf).reason.is_empty())
	_cycle.day_index = 4
	await _tick()
	await _tick()
	for record: AngelFurnitureOrder in _state.orders:
		assert_true(record.issued)
		assert_eq(record.total_price, _old_price)
		assert_eq(record.ready_day, 2)
		assert_eq(record.receiving_hint, _hint)
	var first: Entity = _world.get_entity_by_id(_state.orders[0].output_id)
	var second: Entity = _world.get_entity_by_id(_state.orders[1].output_id)
	assert_ne(first.id, second.id)
	assert_gt(
		(first as Node as Node3D)
		.global_position
		.distance_to((second as Node as Node3D).global_position),
		3.0,
	)
	(first as Node as Node3D).global_position = Vector3(-5, 2, 12)
	_world.remove_entity(second)
	await get_tree().process_frame
	await _tick()
	assert_true(_state.orders[0].received)
	assert_true(_state.orders[1].received)
	snapshot = WorldSnapshotService.capture(_root, 4)
	_restore(snapshot)
	await _tick()
	assert_eq(_wallet.operations.size(), 2)
	assert_eq(_wallet.balance, 2000 - 2 * _old_price)
	assert_null(_world.get_entity_by_id(_state.orders[1].output_id))
	assert_not_null(_world.get_entity_by_id(_state.orders[0].output_id))
	assert_true(_commerce.pending_deliveries.is_empty())


func test_queued_ticket_rejects_world_switch_without_charging_or_issuing_again() -> void:
	_order()
	_cycle.day_index = 2
	for system: System in _world.systems:
		system.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.process(2.0, "TestAngel")
	var other: World = World.new()
	_root.add_child(other)
	ECS.world = other
	_world.flush_command_buffers()
	assert_false(_state.orders[0].issued)
	ECS.world = _world
	other.free()
	await _tick()
	assert_true(_state.orders[0].issued)
	assert_eq(_wallet.operations.size(), 1)


func test_restore_invalidates_old_queued_ticket_then_issues_one_fresh_body() -> void:
	_order()
	_cycle.day_index = 2
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	for system: System in _world.systems:
		system.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.process(2.0, "TestAngel")
	var receiving: C_OrderReceiving = _terminal.get_component(C_OrderReceiving) as C_OrderReceiving
	var old_revision: int = receiving.delivery_revision
	assert_true(receiving.delivery_queued)
	assert_true(WorldSnapshotService.capture(_root, 2).is_empty())
	_restore(snapshot)
	assert_gt(receiving.delivery_revision, old_revision)
	_world.flush_command_buffers()
	assert_false(_state.orders[0].issued)
	await _tick()
	assert_true(_state.orders[0].issued)
	assert_eq(_wallet.operations.size(), 1)


func test_pvz_busy_or_disabled_does_not_own_angel_payment_or_delivery() -> void:
	_commerce.transaction_in_progress = true
	_terminal.open_for(_actor)
	assert_true(_terminal.is_open_for(_actor))
	_terminal.close_panel()
	_order()
	_cycle.day_index = 2
	await _tick()
	assert_true(_state.orders[0].issued)
	assert_true(_commerce.receipts.is_empty())
	assert_true(_commerce.pending_deliveries.is_empty())
	assert_true(_commerce.transaction_in_progress)
	_commerce.transaction_in_progress = false
	assert_eq(_wallet.operations.size(), 1)
#endregion


#region Premutation corruption and synchronous publication
func test_corrupt_angel_records_reject_without_wallet_or_world_mutation() -> void:
	_order()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	var fields: Dictionary
	for entity: Dictionary in snapshot.entities:
		for component: Dictionary in entity.components:
			if component.type == (C_AngelOrders as Script).resource_path:
				fields = component.fields
	var original: Dictionary = fields.duplicate(true)
	var bad_values: Dictionary = {
		"paid": false,
		"issued": true,
		"received": true,
		"ready_day": 3,
		"quantity": 2,
		"terminal_id": "pvz",
		"receiving_id": &"pvz/place",
		"receiving_hint": "",
		"total_price": 1,
		"output_id": "order/pvz",
	}
	for field: String in bad_values:
		fields.merge(original.duplicate(true), true)
		fields.orders[0].fields[field] = bad_values[field]
		assert_false(WorldSnapshotService.can_restore(snapshot, _root), field)
		assert_eq(_wallet.balance, 2000 - _old_price)
		assert_false(_state.orders[0].issued)
	fields.merge(original.duplicate(true), true)
	fields.orders[0].fields.erase("paid")
	assert_false(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(_wallet.operations.size(), 1)


func test_native_publication_guards_snapshot_and_reentrant_confirmation() -> void:
	var offer: AngelFurnitureQuote = _order()
	var results: Array[bool] = []
	_world.entity_added.connect(
		func(entity: Entity) -> void:
			if not entity.id.begins_with("angel-order/"):
				return
			results.append(_state.orders[0].issued)
			results.append(WorldSnapshotService.capture(_root, 2).is_empty())
			results.append(
				AngelFurnitureService.confirm(_actor, offer)
				== AngelFurnitureService.Status.UNAVAILABLE
			),
	)
	_cycle.day_index = 2
	await _tick()
	assert_eq(results, [true, true, true])
	assert_true(_state.orders[0].issued)
	assert_false(_state.transaction_in_progress)
	assert_eq(_wallet.operations.size(), 1)
#endregion
