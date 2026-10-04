extends GutTest
## Проверяет атомарные покупки, постоянные заказы и однократный денежный эффект.

var _world: World = null
var _actor: Entity = null
var _trader: Entity = null
var _commerce: C_Commerce = null
var _wallet: C_Wallet = null
var _cycle: C_DayCycle = null
var _food: DEF_InventoryItem = null
var _med: DEF_InventoryItem = null


#region Тестовое окружение
## Создаёт отдельные кошелёк, каталог, торговца и покупателя с инвентарём.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_InventoryEffect.new())
	_world.add_observer(O_InventoryLifecycle.new())
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_Wallet.new(), C_Commerce.new()]
	_world.add_entity(session)
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_wallet = session.get_component(C_Wallet) as C_Wallet
	_commerce = session.get_component(C_Commerce) as C_Commerce
	_cycle.phase = C_DayCycle.Phase.EVENING
	_wallet.balance = 500
	_food = load("res://content/definitions/gameplay/inventory/def_item_food.tres") as DEF_InventoryItem
	_med = load("res://content/definitions/gameplay/inventory/def_item_med.tres") as DEF_InventoryItem
	_actor = Entity.new()
	_actor.component_resources = [C_Inventory.new()]
	_world.add_entity(_actor)
	_trader = Entity.new()

	var shop: C_Trader = C_Trader.new()
	shop.catalog = [_food, _med]
	_trader.component_resources = [shop]
	_world.add_entity(_trader)


## Удаляет World и освобождает глобальную ссылку ECS.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


#endregion

#region Атомарная покупка
## Одна операция списывает деньги и выдаёт количество один раз; изменение её данных даёт конфликт.
func test_purchase_debits_once_and_grants_owned_quantity_once() -> void:
	assert_eq(CommerceService.purchase(_actor, _trader, _food, 2, &"buy:1"), CommerceService.Status.COMMITTED)
	assert_eq(_wallet.balance, 450)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_commerce.receipts.size(), 1)
	var item: Entity = InventoryService.items(_actor)[0]
	assert_eq(InventoryService.owner_for(item), _actor)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)
	assert_eq(CommerceService.purchase(_actor, _trader, _food, 2, &"buy:1"), CommerceService.Status.DUPLICATE)
	assert_eq(_wallet.balance, 450)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)
	assert_eq(CommerceService.purchase(_actor, _trader, _med, 2, &"buy:1"), CommerceService.Status.CONFLICT)
	assert_eq(CommerceService.purchase(_actor, _trader, _food, 1, &"buy:1"), CommerceService.Status.CONFLICT)


## Недостаток денег не оставляет предмет или чек и позволяет повторить запрос после пополнения.
func test_insufficient_money_retains_no_probe_item_or_receipt_and_can_retry() -> void:
	_wallet.balance = 10
	assert_eq(CommerceService.purchase(_actor, _trader, _food, 1, &"buy:retry"), CommerceService.Status.INSUFFICIENT_FUNDS)
	assert_eq(_wallet.balance, 10)
	assert_true(_wallet.operations.is_empty())
	assert_true(_commerce.receipts.is_empty())
	assert_true(_world.query.with_all([C_InventoryItem]).execute().is_empty())
	_wallet.balance = 30
	assert_eq(CommerceService.purchase(_actor, _trader, _food, 1, &"buy:retry"), CommerceService.Status.COMMITTED)
	assert_eq(_wallet.balance, 5)


## Заполненный инвентарь или отсутствующая позиция каталога не списывают деньги.
func test_full_inventory_and_bad_catalog_do_not_charge() -> void:
	(_actor.get_component(C_Inventory) as C_Inventory).maximum_stacks = 1
	assert_eq(CommerceService.purchase(_actor, _trader, _food, 10, &"fill"), CommerceService.Status.COMMITTED)
	var balance: int = _wallet.balance
	assert_eq(CommerceService.purchase(_actor, _trader, _med, 1, &"blocked"), CommerceService.Status.INVENTORY_FULL)
	assert_eq(_wallet.balance, balance)
	assert_eq(_commerce.receipts.size(), 1)
	var wrap: DEF_InventoryItem = load("res://content/definitions/gameplay/inventory/def_item_bubble_wrap.tres") as DEF_InventoryItem
	assert_eq(CommerceService.purchase(_actor, _trader, wrap, 1, &"not-stocked"), CommerceService.Status.INVALID)
	assert_eq(_wallet.balance, balance)


#endregion

#region Постоянные заказы и каталог
## Утренний/вечерний заказ создаёт постоянную доставку на следующий день, без немедленного предмета.
func test_orders_in_morning_and_evening_debit_once_and_create_next_day_record() -> void:
	_cycle.phase = C_DayCycle.Phase.MORNING
	assert_eq(CommerceService.order(_actor, _food, 3, &"order:1"), CommerceService.Status.COMMITTED)
	assert_eq(_wallet.balance, 425)
	assert_eq(_commerce.pending_deliveries.size(), 1)
	var delivery: PendingDelivery = _commerce.pending_deliveries[0]
	assert_eq(delivery.delivery_day, 2)
	assert_eq(delivery.ordered_day, 1)
	assert_eq(delivery.quantity, 3)
	assert_false(delivery.fulfilled)
	assert_true(InventoryService.items(_actor).is_empty(), "Order is a durable delivery, not an immediate grant")
	_cycle.phase = C_DayCycle.Phase.EVENING
	assert_eq(CommerceService.order(_actor, _food, 3, &"order:1"), CommerceService.Status.DUPLICATE)
	assert_eq(_commerce.pending_deliveries.size(), 1)
	assert_eq(_wallet.balance, 425)
	assert_eq(CommerceService.purchase(_actor, _trader, _food, 3, &"order:1"), CommerceService.Status.CONFLICT)
	assert_eq(CommerceService.order(_actor, _med, 1, &"order:2"), CommerceService.Status.COMMITTED)
	assert_eq(_wallet.balance, 365)


## Неверная фаза, количество, ID и смерть отклоняют покупку без фиксации.
func test_phase_quantity_invalid_ids_and_dead_actor_are_rejected_without_commit() -> void:
	_cycle.phase = C_DayCycle.Phase.DAY
	assert_eq(CommerceService.order(_actor, _food, 1, &"day"), CommerceService.Status.WRONG_PHASE)
	assert_eq(CommerceService.purchase(_actor, _trader, _food, 1, &"day"), CommerceService.Status.WRONG_PHASE)
	_cycle.phase = C_DayCycle.Phase.NIGHT
	assert_eq(CommerceService.order(_actor, _food, 1, &"night"), CommerceService.Status.WRONG_PHASE)
	_cycle.phase = C_DayCycle.Phase.EVENING
	for quantity: int in [0, -1, 11]:
		assert_eq(CommerceService.order(_actor, _food, quantity, &"bad"), CommerceService.Status.INVALID)
	assert_eq(CommerceService.order(_actor, _food, 1, &""), CommerceService.Status.INVALID)
	_actor.add_component(C_Death.new())
	assert_eq(CommerceService.order(_actor, _food, 1, &"dead"), CommerceService.Status.INVALID)
	assert_eq(CommerceService.purchase(_actor, _trader, _food, 1, &"dead"), CommerceService.Status.INVALID)
	assert_eq(_wallet.balance, 500)
	assert_true(_commerce.receipts.is_empty())


## Глубокая копия сохраняет заказы независимо; последовательность предотвращает повтор ID.
func test_persistent_records_copy_and_serial_prevent_request_id_collision() -> void:
	var first_id: StringName = CommerceService.next_id("order")
	assert_eq(CommerceService.order(_actor, _food, 1, first_id), CommerceService.Status.COMMITTED)
	var snapshot: C_Commerce = _commerce.duplicate(true) as C_Commerce
	assert_eq(snapshot.next_request, 1)
	assert_eq(snapshot.pending_deliveries[0].delivery_id, first_id)
	assert_eq(snapshot.receipts[0].total_price, 25)
	assert_ne(CommerceService.next_id("order"), first_id)
	snapshot.pending_deliveries[0].fulfilled = true
	assert_false(_commerce.pending_deliveries[0].fulfilled)


## Учётная стоимость коробки отличается от рыночной цены содержимого; upgrade-заготовки имеют свои ID.
func test_authored_market_contents_and_upgrade_stubs_are_distinct_data() -> void:
	var supply: DEF_Delivery = load("res://content/definitions/gameplay/deliveries/def_delivery_morning_supply.tres") as DEF_Delivery
	var compared: bool = false
	for parcel: DEF_Package in supply.packages:
		if parcel.content_item_key == &"bubble_wrap":
			var wrap: DEF_InventoryItem = load("res://content/definitions/gameplay/inventory/def_item_bubble_wrap.tres") as DEF_InventoryItem
			assert_eq(parcel.content_quantity, 4)
			assert_ne(parcel.accounting_value, wrap.market_price * parcel.content_quantity)
			compared = true
	assert_true(compared)
	for key: String in ["label_printer", "cart", "better_scanner", "storage_upgrade"]:
		var upgrade: DEF_Upgrade = load("res://content/definitions/gameplay/commerce/def_upgrade_%s.tres" % key) as DEF_Upgrade
		assert_not_null(upgrade)
		assert_eq(upgrade.key, StringName(key))

#endregion
