extends GutTest
## Проверяет физическую выдачу мебели, оплаченную доставку торговца и постоянные записи покупки.

const FOOD_PATH: String = "res://content/domains/inventory/definitions/def_item_food.tres"

var _root: Node3D
var _world: World
var _actor: Entity
var _trader: E_NpcCharacter
var _shop: C_Trader
var _commerce: C_Commerce
var _cycle: C_DayCycle
var _wallet: C_Wallet
var _shelf: DEF_InventoryItem
var _floor: StaticBody3D


#region Торговая площадка и тестовые участники
## Создаёт торговую площадку с реальной опорой, кошельком и мебелью авторского каталога.
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	_world.add_observer(O_InventoryLifecycle.new())
	var session: Entity = Entity.new()
	session.name = "Session"
	session.component_resources = [C_DayCycle.new(), C_Wallet.new(), C_Commerce.new()]
	_root.add_child(session)
	session.owner = _root
	FixturePlacedIdentity.assign(_root, session, &"session")
	EntityCompositionFixture.register(_world, session, false)
	_commerce = session.get_component(C_Commerce) as C_Commerce
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_wallet = session.get_component(C_Wallet) as C_Wallet
	_cycle.phase = C_DayCycle.Phase.EVENING
	_wallet.balance = 1000
	_actor = Entity.new()
	_actor.name = "Player"
	_actor.component_resources = [C_Inventory.new(), C_GrabControl.new()]
	_root.add_child(_actor)
	_actor.owner = _root
	FixturePlacedIdentity.assign(_root, _actor, &"actor")
	EntityCompositionFixture.register(_world, _actor, false)
	_trader = (load("res://content/domains/commerce/entities/trader.tscn") as PackedScene).instantiate() as E_NpcCharacter
	(_trader as Node as RigidBody3D).freeze = true
	_root.add_child(_trader)
	_trader.owner = _root
	FixturePlacedIdentity.assign(_root, _trader, &"trader")
	EntityCompositionFixture.register(_world, _trader, false)
	_shop = _trader.get_component(C_Trader) as C_Trader
	_shelf = load("res://content/domains/inventory/definitions/def_item_large_shelf.tres") as DEF_InventoryItem
	_floor = _block(Vector3(0, -0.1, 0), Vector3(40, 0.2, 40))
	await get_tree().physics_frame
	await get_tree().physics_frame


## Закрывает торговые панели до удаления World и его физической геометрии.
func after_each() -> void:
	for child: Node in _actor.get_children():
		if child is CommercePanel:
			(child as CommercePanel).close_panel()
	await get_tree().process_frame
	_world.purge(false)
	_root.free()
	ECS.world = null
	await get_tree().process_frame


func _block(position: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = position
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	_root.add_child(body)
	return body


func _goods(key: String) -> Entity:
	for entity: Entity in _world.query.with_all([C_PersistentIdentity]).execute():
		if (entity.get_component(C_PersistentIdentity) as C_PersistentIdentity).key == key:
			return entity
	return null


func _home() -> Entity:
	var zone: Entity = (load("res://content/domains/commerce/entities/order_receiving.tscn") as PackedScene).instantiate() as Entity
	(zone as Node as Node3D).position = Vector3(-6, 0.22, -6)
	EntityCompositionFixture.register(_world, zone)
	return zone


#endregion

#region Физическая выдача и каталог
## Покупка создаёт тяжёлую фиксируемую полку рядом с торговцем один раз, вне виртуального инвентаря.
func test_purchase_spawns_massive_anchorable_shelf_beside_trader_without_inventory_or_repeat() -> void:
	(_actor.get_component(C_Inventory) as C_Inventory).maximum_stacks = 0
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1, &"shelf/one"), CommerceService.Status.COMMITTED)
	var shelf: Entity = _goods("purchase/shelf/one")
	assert_not_null(shelf)
	assert_true(shelf.has_component(C_Anchorable))
	assert_true(shelf.has_component(C_Grabbable))
	assert_false(shelf.has_component(C_InventoryItem))

	var body: RigidBody3D = shelf as Node as RigidBody3D
	assert_eq(body.mass, 75.0)
	assert_eq(body.global_position.x, 3.0)
	assert_almost_eq(body.global_position.y, 1.55, 0.001)
	assert_eq(body.get_parent(), _root, "Goods never move as children of the trader")
	assert_eq(_wallet.balance, 820)
	assert_true(InventoryService.items(_actor).is_empty())
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1, &"shelf/one"), CommerceService.Status.DUPLICATE)
	assert_eq(_world.query.with_all([C_Anchorable]).execute().size(), 1)
	assert_eq(_wallet.operations.size(), 1)


## Занятое или неподдержанное место не списывает оплату; успешный повтор атомарен.
func test_blocked_or_unsupported_zone_never_charges_and_paid_retry_is_atomic() -> void:
	var blocker: StaticBody3D = _block(Vector3(5, 1.5, -3), Vector3(9, 3, 8))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1, &"blocked"), CommerceService.Status.SPAWN_BLOCKED)
	assert_eq(_wallet.balance, 1000)
	assert_true(_commerce.receipts.is_empty())
	blocker.queue_free()
	_floor.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1, &"unsupported"), CommerceService.Status.SPAWN_BLOCKED)
	assert_eq(_wallet.balance, 1000)
	_floor = _block(Vector3(0, -0.1, 0), Vector3(40, 0.2, 40))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_wallet.balance = 10
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1, &"retry"), CommerceService.Status.INSUFFICIENT_FUNDS)
	assert_null(_goods("purchase/retry"))
	assert_false(_commerce.transaction_in_progress)
	_wallet.balance = 200
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1, &"retry"), CommerceService.Status.COMMITTED)
	assert_eq(_wallet.balance, 20)


## Stable-key rejection precedes Wallet/receipt commit and preserves the existing actor.
func test_furniture_composition_collision_never_charges_or_replaces_goods() -> void:
	var existing: Entity = Entity.new()
	var identity: C_PersistentIdentity = C_PersistentIdentity.new()
	identity.key = "purchase/composition/collision"
	existing.component_resources = [identity]
	EntityCompositionFixture.register(_world, existing)
	var before_count: int = _world.entities.size()
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1,
		&"composition/collision"), CommerceService.Status.SPAWN_BLOCKED)
	assert_eq(_wallet.balance, 1000)
	assert_true(_wallet.operations.is_empty())
	assert_true(_commerce.receipts.is_empty())
	assert_false(_commerce.transaction_in_progress)
	assert_eq(_world.entities.size(), before_count)
	assert_same(_goods(identity.key), existing)
	assert_false(existing.is_queued_for_deletion())


## Личный каталог и расписание торговца не подменяются каталогом терминала.
func test_configured_catalog_and_schedule_are_independent_from_terminal_orders() -> void:
	var profile: DEF_TraderProfile = (load("res://content/domains/commerce/definitions/def_trader_medical.tres") as DEF_TraderProfile).duplicate() as DEF_TraderProfile
	profile.catalog = [_shelf]
	_shop.profile = profile
	assert_false(_shelf in _commerce.catalog)
	_cycle.phase = C_DayCycle.Phase.MORNING
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1, &"schedule"), CommerceService.Status.WRONG_PHASE)
	_cycle.day_index = 2
	assert_true(TraderCatalogRules.is_open(_shop, _cycle))
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1, &"schedule"), CommerceService.Status.COMMITTED)
	_cycle.day_index = 3
	assert_false(TraderCatalogRules.is_open(_shop, _cycle))
	assert_eq(CommerceService.order(_actor, _shelf, 1, &"terminal"), CommerceService.Status.INVALID)
	assert_eq(_wallet.balance, 820)


#endregion

#region Оплаченная доставка торговца
## Расходные заказы создают реальные физические предметы и освобождают очередь получения.
func test_consumable_deliveries_create_physical_pickups_and_do_not_stall_queue() -> void:
	var zone: Entity = _home()
	var receiving: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	for key: String in ["food", "med", "bubble_wrap", "npc_meat"]:
		var item: DEF_InventoryItem = load("res://content/domains/inventory/definitions/def_item_%s.tres" % key) as DEF_InventoryItem
		assert_not_null(item)
		assert_true(OrderDeliveryService.can_fulfill_definition(item))
		var delivery: PendingDelivery = PendingDelivery.new()
		delivery.delivery_id = key
		delivery.delivery_day = 2
		delivery.item = item
		delivery.quantity = 1
		_commerce.pending_deliveries.append(delivery)
		assert_true(OrderDeliveryService.fulfill_one(zone, receiving, _commerce, 2))
		var goods: Entity = _goods("order/%s" % key)
		assert_not_null(goods)
		assert_true((goods as Node) is RigidBody3D)
		assert_false((goods as Node as RigidBody3D).freeze)
		assert_true(delivery.fulfilled)
		assert_false(receiving.blocked)
		await get_tree().physics_frame
	assert_false(OrderDeliveryService.fulfill_one(zone, receiving, _commerce, 2))


## A physical delivery cannot replace a live Entity with the paid order's requested ID.
func test_delivery_composition_collision_preserves_unfulfilled_order_and_registry() -> void:
	var zone: Entity = _home()
	var receiving: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	var food: DEF_InventoryItem = load(
		FOOD_PATH) as DEF_InventoryItem
	for definition: DEF_InventoryItem in [food, _shelf]:
		var delivery: PendingDelivery = PendingDelivery.new()
		delivery.delivery_id = StringName("composition/%s" % definition.key)
		delivery.item = definition
		delivery.quantity = 1
		delivery.delivery_day = 2
		_commerce.pending_deliveries = [delivery]
		var existing: Entity = Entity.new()
		existing.id = OrderDeliveryService.key_for(delivery)
		EntityCompositionFixture.register(_world, existing)
		var before_count: int = _world.entities.size()
		assert_false(OrderDeliveryService.fulfill_one(zone, receiving, _commerce, 2))
		assert_true(receiving.blocked)
		assert_false(delivery.fulfilled)
		assert_eq(_world.entities.size(), before_count)
		assert_same(_world.entity_id_registry[existing.id], existing)
		assert_false(existing.is_queued_for_deletion())
		assert_false(receiving.goods.has(existing.id))
		assert_true(receiving.reservations.is_empty())
	assert_eq(_wallet.balance, 1000)
	assert_true(_wallet.operations.is_empty())


## Оплаченный заказ ждёт дня и места; сохранение и повтор не дублируют мебель.
func test_paid_home_delivery_waits_for_day_and_space_then_fulfills_once_after_save() -> void:
	assert_eq(CommerceService.home_delivery(_actor, _trader, _shelf, 1, &"home/one"), CommerceService.Status.COMMITTED)
	assert_eq(_wallet.balance, 720)
	assert_eq(_commerce.receipts[0].total_price, 280)
	assert_eq(_commerce.receipts[0].delivery_fee, 100)
	assert_eq(CommerceService.home_delivery(_actor, _trader, _shelf, 1, &"home/one"), CommerceService.Status.DUPLICATE)
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1, &"home/one"), CommerceService.Status.CONFLICT)
	var copy: C_Commerce = C_Commerce.new()
	assert_true(SaveDataCodec.apply_fields(copy, SaveDataCodec.component_data(_commerce).fields as Dictionary))
	assert_eq(copy.receipts[0].delivery_fee, 100)
	assert_eq(copy.pending_deliveries[0].delivery_day, 2)

	var zone: Entity = _home()
	var receiving: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	assert_false(OrderDeliveryService.fulfill_one(zone, receiving, copy, 1))
	var blocker: StaticBody3D = _block(Vector3(-5, 1.5, -5), Vector3(8, 3, 8))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(OrderDeliveryService.fulfill_one(zone, receiving, copy, 2))
	assert_true(receiving.blocked)
	assert_false(copy.pending_deliveries[0].fulfilled)
	blocker.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	assert_true(OrderDeliveryService.fulfill_one(zone, receiving, copy, 2))

	var shelf: Entity = _goods("order/home/one")
	assert_not_null(shelf)
	assert_eq((shelf as Node as RigidBody3D).mass, 75.0)
	assert_true(copy.pending_deliveries[0].fulfilled)
	assert_false(OrderDeliveryService.fulfill_one(zone, receiving, copy, 2))
	copy.pending_deliveries[0].fulfilled = false
	assert_true(OrderDeliveryService.fulfill_one(zone, receiving, copy, 2), "Existing operation identity repairs stale fulfillment guard")
	assert_eq(_world.query.with_all([C_Anchorable]).execute().size(), 1)
	assert_eq(_wallet.operations.size(), 1)


## Непригодная сцена отклоняется; панель различает самовывоз и оплаченную доставку торговца.
func test_courier_rejects_unfulfillable_definition_and_trader_panel_offers_separate_delivery() -> void:
	var invalid: DEF_InventoryItem = _shelf.duplicate() as DEF_InventoryItem
	invalid.world_pickup_scene = ""
	var profile: DEF_TraderProfile = _shop.profile.duplicate() as DEF_TraderProfile
	profile.catalog = [invalid]
	_shop.profile = profile
	assert_eq(CommerceService.home_delivery(_actor, _trader, invalid, 1, &"invalid"), CommerceService.Status.INVALID)
	assert_eq(_wallet.balance, 1000)
	invalid.world_pickup_scene = "res://tests/fixtures/invalid_furniture.tscn"
	assert_eq(CommerceService.home_delivery(_actor, _trader, invalid, 1, &"disabled_shape"), CommerceService.Status.INVALID)
	invalid.kind = DEF_InventoryItem.Kind.FOOD
	invalid.world_pickup_scene = "res://tests/fixtures/invalid_delivery_pickup.tscn"
	assert_eq(CommerceService.home_delivery(_actor, _trader, invalid, 1, &"missing_item"), CommerceService.Status.INVALID)
	assert_eq(_wallet.balance, 1000)
	assert_true(_wallet.operations.is_empty())
	assert_true(_commerce.receipts.is_empty())
	assert_true(_commerce.pending_deliveries.is_empty())
	profile.catalog = [_shelf]

	var panel: CommercePanel = CommercePanelFactory.open(_actor, _trader)
	assert_not_null(panel)
	assert_eq(panel._offers.get_child_count(), 1)
	var row: Node = panel._offers.get_child(0)
	assert_eq(row.get_child_count(), 1, "Delivery appears only in the purchase popup")
	(row.get_child(0) as Button).pressed.emit()
	assert_eq(_wallet.balance, 1000, "Opening the choice does not charge")
	assert_true(panel._purchase_dialog.visible)
	assert_eq(panel._purchase_dialog.title, "Доставить или заберёшь сам?")
	assert_eq(panel._purchase_dialog.get_ok_button().text, "Сам")
	assert_eq(panel._delivery_button.text, "Доставить +100$")
	assert_true(panel._purchase_dialog.dialog_text.contains("280$"))
	assert_true(panel._purchase_dialog.dialog_text.contains("дня 2"))
	await get_tree().process_frame
	panel._delivery_button.pressed.emit()
	assert_eq(_wallet.balance, 720)
	assert_eq(_commerce.pending_deliveries.size(), 1)
	assert_true(_world.query.with_all([C_Anchorable]).execute().is_empty())

#endregion

#region Rejected paid pickup construction
## A malformed prefab cannot fulfill an order, publish goods or leak a detached instance.
func test_pickup_delivery_rejection_preserves_pending_order_and_releases_instance() -> void:
	var definition: DEF_InventoryItem = load(
		FOOD_PATH
	).duplicate() as DEF_InventoryItem
	var delivery: PendingDelivery = PendingDelivery.new()
	delivery.delivery_id = "rejected-pickup"
	delivery.delivery_day = 2
	delivery.item = definition
	delivery.quantity = 3
	_commerce.pending_deliveries.append(delivery)
	var zone: Entity = _home()
	var receiving: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	var entities_before: int = _world.entities.size()
	var children_before: int = zone.get_child_count()

	for scene_path: String in [
		"res://tests/fixtures/invalid_furniture.tscn",
		"res://tests/fixtures/invalid_delivery_pickup.tscn",
		"res://tests/fixtures/missing_pickup_stack.tscn",
		"res://tests/fixtures/" + "nonexistent_pickup.tscn",
	]:
		definition.world_pickup_scene = scene_path
		assert_false(OrderDeliveryService.fulfill_one(zone, receiving, _commerce, 2))
		assert_true(receiving.blocked)
		assert_false(delivery.fulfilled)
		assert_eq(delivery.quantity, 3)
		assert_eq(_commerce.pending_deliveries, [delivery])
		assert_true(_commerce.receipts.is_empty())
		assert_eq(_wallet.balance, 1000)
		assert_true(_wallet.operations.is_empty())
		assert_null(_goods(OrderDeliveryService.key_for(delivery)))
		assert_eq(_world.entities.size(), entities_before)
		assert_eq(zone.get_child_count(), children_before)
		assert_no_new_orphans(scene_path)
#endregion
