extends RefCounted
## Синхронная граница оплаты и выдачи покупок; журнал чеков защищает от повторов.
class_name CommerceService

enum Status { COMMITTED, DUPLICATE, INVALID, CONFLICT, INSUFFICIENT_FUNDS, INVENTORY_FULL, WRONG_PHASE, SPAWN_BLOCKED }
const WALLET_PREFIX: String = "commerce/"
const FURNITURE_COLUMNS: int = 2
const FURNITURE_ROWS: int = 2
const FURNITURE_SPACING: Vector2 = Vector2(3.5, 2.5)


#region Состояние и ID запросов
## Возвращает торговое состояние сессионной сущности или null.
static func current() -> C_Commerce:
	if not is_instance_valid(ECS.world):
		return null

	var owner: Entity = ECS.world.query.with_all([C_Commerce, C_DayCycle, C_Wallet]).execute_one()
	return owner.get_component(C_Commerce) as C_Commerce if owner != null else null


## Увеличивает сохраняемый счётчик запросов вне активной транзакции; отказ даёт пустой ID.
static func next_id(prefix: String) -> StringName:
	var state: C_Commerce = current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if state == null or cycle == null or state.transaction_in_progress:
		return &""

	state.next_request += 1
	return StringName("%s:%d:%d" % [prefix, cycle.day_index, state.next_request])


#endregion

#region Покупка у торговца
## Проверяет торговца и место/инвентарь, затем оплачивает и выдаёт товар однократно.
static func purchase(actor: Entity, trader: Entity, item: DEF_InventoryItem, quantity: int, operation_id: StringName) -> Status:
	var state: C_Commerce = current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var valid: Status = _validate(state, cycle, item, quantity, operation_id, PurchaseReceipt.Mode.PURCHASE, false)
	if valid != Status.COMMITTED:
		return _trace_result(valid, operation_id, &"commerce.purchase", actor, item)
	if not GrabQueries.holder_available(actor) or actor.has_component(C_Death) or not GrabQueries.holder_available(trader):
		return _trace_result(Status.INVALID, operation_id, &"commerce.purchase", actor, item)

	var shop: C_Trader = trader.get_component(C_Trader) as C_Trader
	if shop == null or trader.has_component(C_Death) or item not in TraderCatalogRules.catalog(shop):
		return _trace_result(Status.INVALID, operation_id, &"commerce.purchase", actor, item)
	if not TraderCatalogRules.is_open(shop, cycle):
		return _trace_result(Status.WRONG_PHASE, operation_id, &"commerce.purchase", actor, item)
	if item.kind == DEF_InventoryItem.Kind.FURNITURE:
		var furniture_status: Status = _purchase_furniture(
			trader, shop, item, quantity, operation_id, state, cycle
		)
		return _trace_result(furniture_status, operation_id, &"commerce.purchase", actor, item)
	if not actor.has_component(C_Inventory):
		return _trace_result(Status.INVALID, operation_id, &"commerce.purchase", actor, item)

	state.transaction_in_progress = true
	var grant: Entity = Entity.new()
	var stack: C_InventoryItem = C_InventoryItem.new()
	stack.definition = item
	stack.quantity = quantity
	grant.component_resources = [stack]
	ECS.world.add_entity(grant)
	if not InventoryService.can_transfer(grant, actor):
		ECS.world.remove_entity(grant)
		state.transaction_in_progress = false
		return _trace_result(Status.INVENTORY_FULL, operation_id, &"commerce.purchase", actor, item)

	var money_status: Status = _pay(item, quantity, operation_id, cycle.day_index)
	if money_status != Status.COMMITTED:
		ECS.world.remove_entity(grant)
		state.transaction_in_progress = false
		return _trace_result(money_status, operation_id, &"commerce.purchase", actor, item)
	# Расчёт кошелька синхронен и не меняет инвентарь: проверенный перенос остаётся допустимым.
	var transferred: bool = InventoryService.transfer(grant, actor)
	assert(transferred, "Commerce grant must honor its validated synchronous Inventory contract")
	_record(state, item, quantity, operation_id, cycle.day_index, PurchaseReceipt.Mode.PURCHASE)
	state.transaction_in_progress = false
	return _trace_result(Status.COMMITTED, operation_id, &"commerce.purchase", actor, item)


static func _purchase_furniture(trader: Entity, shop: C_Trader, item: DEF_InventoryItem, quantity: int, operation_id: StringName, state: C_Commerce, cycle: C_DayCycle) -> Status:
	if quantity != 1:
		return Status.INVALID

	var zone: Node3D = trader.get_node_or_null(shop.furniture_pickup_path) as Node3D
	var parent: Node3D = trader.get_parent() as Node3D
	if zone == null or parent == null:
		return Status.SPAWN_BLOCKED

	state.transaction_in_progress = true
	var proposal: PreparedFurniture = null
	for index: int in FURNITURE_COLUMNS * FURNITURE_ROWS:
		var pose: Transform3D = zone.global_transform
		pose.origin += pose.basis * Vector3((index % FURNITURE_COLUMNS) * FURNITURE_SPACING.x, 0, -(index / FURNITURE_COLUMNS) * FURNITURE_SPACING.y)
		proposal = FurniturePlacement.prepare(item, parent, pose)
		if proposal != null:
			break
	if proposal == null:
		state.transaction_in_progress = false
		return Status.SPAWN_BLOCKED

	var paid: Status = _pay(item, quantity, operation_id, cycle.day_index)
	if paid != Status.COMMITTED:
		proposal.entity.free()
		state.transaction_in_progress = false
		return paid

	_record(state, item, quantity, operation_id, cycle.day_index, PurchaseReceipt.Mode.PURCHASE)
	FurniturePlacement.commit(proposal, "purchase/%s" % operation_id)
	state.transaction_in_progress = false
	return Status.COMMITTED


#endregion

#region Отложенные оплаченные заказы
## Оплачивает товар и доставку торговца, сохраняя отложенный заказ с датой исполнения.
static func home_delivery(actor: Entity, trader: Entity, item: DEF_InventoryItem, quantity: int, operation_id: StringName) -> Status:
	var state: C_Commerce = current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var valid: Status = _validate(state, cycle, item, quantity, operation_id, PurchaseReceipt.Mode.TRADER_DELIVERY, false)
	if valid != Status.COMMITTED:
		return _trace_result(valid, operation_id, &"commerce.home_delivery", actor, item)
	if not GrabQueries.holder_available(actor) or actor.has_component(C_Death) or not GrabQueries.holder_available(trader) or trader.has_component(C_Death):
		return _trace_result(Status.INVALID, operation_id, &"commerce.home_delivery", actor, item)

	var shop: C_Trader = trader.get_component(C_Trader) as C_Trader
	if not TraderCatalogRules.can_deliver(shop, item) or quantity != 1 or item not in TraderCatalogRules.catalog(shop):
		return _trace_result(Status.INVALID, operation_id, &"commerce.home_delivery", actor, item)
	if not TraderCatalogRules.is_open(shop, cycle):
		return _trace_result(Status.WRONG_PHASE, operation_id, &"commerce.home_delivery", actor, item)

	var profile: DEF_TraderProfile = shop.profile
	if profile.delivery_fee < 0 or profile.delivery_delay_days < 1 or profile.delivery_fee > WalletService.MAX_AMOUNT - item.market_price * quantity or (item.kind == DEF_InventoryItem.Kind.FURNITURE and quantity != 1):
		return _trace_result(Status.INVALID, operation_id, &"commerce.home_delivery", actor, item)
	if not OrderDeliveryService.can_fulfill_definition(item):
		return _trace_result(Status.INVALID, operation_id, &"commerce.home_delivery", actor, item)

	state.transaction_in_progress = true
	var paid: Status = _pay(item, quantity, operation_id, cycle.day_index, profile.delivery_fee)
	if paid != Status.COMMITTED:
		state.transaction_in_progress = false
		return _trace_result(paid, operation_id, &"commerce.home_delivery", actor, item)

	var delivery: PendingDelivery = PendingDelivery.new()
	delivery.delivery_id = operation_id
	delivery.item = item
	delivery.quantity = quantity
	delivery.ordered_day = cycle.day_index
	delivery.delivery_day = cycle.day_index + profile.delivery_delay_days
	state.pending_deliveries.append(delivery)
	_record(state, item, quantity, operation_id, cycle.day_index, PurchaseReceipt.Mode.TRADER_DELIVERY, profile.delivery_fee)
	state.transaction_in_progress = false
	return _trace_result(Status.COMMITTED, operation_id, &"commerce.home_delivery", actor, item)


## Оплачивает заказ терминала утром/вечером для физической доставки следующим днём.
static func order(actor: Entity, item: DEF_InventoryItem, quantity: int, operation_id: StringName) -> Status:
	var state: C_Commerce = current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var valid: Status = _validate(state, cycle, item, quantity, operation_id, PurchaseReceipt.Mode.ORDER)
	if valid != Status.COMMITTED:
		return _trace_result(valid, operation_id, &"commerce.order", actor, item)
	if cycle.phase not in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.EVENING]:
		return _trace_result(Status.WRONG_PHASE, operation_id, &"commerce.order", actor, item)
	if not GrabQueries.holder_available(actor) or actor.has_component(C_Death):
		return _trace_result(Status.INVALID, operation_id, &"commerce.order", actor, item)

	state.transaction_in_progress = true
	var money_status: Status = _pay(item, quantity, operation_id, cycle.day_index)
	if money_status != Status.COMMITTED:
		state.transaction_in_progress = false
		return _trace_result(money_status, operation_id, &"commerce.order", actor, item)

	var delivery: PendingDelivery = PendingDelivery.new()
	delivery.delivery_id = operation_id
	delivery.item = item
	delivery.quantity = quantity
	delivery.ordered_day = cycle.day_index
	delivery.delivery_day = cycle.day_index + 1
	state.pending_deliveries.append(delivery)
	_record(state, item, quantity, operation_id, cycle.day_index, PurchaseReceipt.Mode.ORDER)
	state.transaction_in_progress = false
	return _trace_result(Status.COMMITTED, operation_id, &"commerce.order", actor, item)


#endregion

#region Проверка и денежный журнал
static func _validate(state: C_Commerce, cycle: C_DayCycle, item: DEF_InventoryItem, quantity: int, operation_id: StringName, mode: PurchaseReceipt.Mode, terminal_catalog: bool = true) -> Status:
	if state == null or cycle == null or state.transaction_in_progress or operation_id.is_empty() or item == null or item.key.is_empty() or quantity < 1 or quantity > item.maximum_stack or item.market_price < 0 or item.market_price > WalletService.MAX_AMOUNT or quantity * item.market_price > WalletService.MAX_AMOUNT:
		return Status.INVALID
	if terminal_catalog and item not in state.catalog:
		return Status.INVALID

	for receipt: PurchaseReceipt in state.receipts:
		if receipt.operation_id == operation_id:
			return Status.DUPLICATE if receipt.item_key == item.key and receipt.quantity == quantity and receipt.mode == mode else Status.CONFLICT
	return Status.COMMITTED


static func _pay(item: DEF_InventoryItem, quantity: int, operation_id: StringName, day_index: int, delivery_fee: int = 0) -> Status:
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = StringName(WALLET_PREFIX + String(operation_id))
	operation.reason = MoneyOperation.Reason.PURCHASE
	operation.amount = item.market_price * quantity + delivery_fee
	operation.day_index = day_index
	match WalletService.submit(operation):
		WalletService.Status.COMMITTED:
			return Status.COMMITTED

		WalletService.Status.INSUFFICIENT_FUNDS:
			return Status.INSUFFICIENT_FUNDS

		WalletService.Status.DUPLICATE, WalletService.Status.CONFLICT:
			return Status.CONFLICT
	return Status.INVALID


static func _record(state: C_Commerce, item: DEF_InventoryItem, quantity: int, operation_id: StringName, day_index: int, mode: PurchaseReceipt.Mode, delivery_fee: int = 0) -> void:
	var receipt: PurchaseReceipt = PurchaseReceipt.new()
	receipt.operation_id = operation_id
	receipt.mode = mode
	receipt.item_key = item.key
	receipt.quantity = quantity
	receipt.total_price = item.market_price * quantity + delivery_fee
	receipt.delivery_fee = delivery_fee
	receipt.day_index = day_index
	state.receipts.append(receipt)

#endregion

#region Boundary diagnostics
static func _trace_result(
	status: Status, operation_id: StringName, operation: StringName,
	actor: Entity, item: DEF_InventoryItem,
) -> Status:
	var trace_stage: BoundaryTraceEntry.Stage = BoundaryTraceEntry.Stage.REJECTED
	if status == Status.COMMITTED:
		trace_stage = BoundaryTraceEntry.Stage.COMPLETED
	elif status == Status.DUPLICATE:
		trace_stage = BoundaryTraceEntry.Stage.DUPLICATE
	var reason: StringName = StringName(String(Status.keys()[status]).to_lower())
	var target_id: String = String(item.key) if item != null else ""
	BoundaryTrace.record(operation, operation_id, trace_stage, reason,
		BoundaryTrace.identity(actor), target_id)
	return status
#endregion
