extends RefCounted
class_name CommerceService

enum Status { COMMITTED, DUPLICATE, INVALID, CONFLICT, INSUFFICIENT_FUNDS, INVENTORY_FULL, WRONG_PHASE }
const WALLET_PREFIX: String = "commerce/"


static func current() -> C_Commerce:
	if not is_instance_valid(ECS.world):
		return null
	var owner: Entity = ECS.world.query.with_all([C_Commerce, C_DayCycle, C_Wallet]).execute_one()
	return owner.get_component(C_Commerce) as C_Commerce if owner != null else null


static func next_id(prefix: String) -> StringName:
	var state: C_Commerce = current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if state == null or cycle == null or state.transaction_in_progress:
		return &""
	state.next_request += 1
	return StringName("%s:%d:%d" % [prefix, cycle.day_index, state.next_request])


static func purchase(actor: Entity, trader: Entity, item: DEF_InventoryItem, quantity: int, operation_id: StringName) -> Status:
	var state: C_Commerce = current()
	var cycle: C_DayCycle = DayPhaseService.current()
	var valid: Status = _validate(state, cycle, item, quantity, operation_id, PurchaseReceipt.Mode.PURCHASE)
	if valid != Status.COMMITTED:
		return valid
	if cycle.phase != C_DayCycle.Phase.EVENING:
		return Status.WRONG_PHASE
	if not GrabService.holder_available(actor) or actor.has_component(C_Death) or not actor.has_component(C_Inventory) or not EntityAvailability.contains(trader, ECS.world):
		return Status.INVALID
	var shop: C_Trader = trader.get_component(C_Trader) as C_Trader
	if shop == null or trader.has_component(C_Death) or item not in shop.catalog:
		return Status.INVALID
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
		return Status.INVENTORY_FULL
	var money_status: Status = _pay(item, quantity, operation_id, cycle.day_index)
	if money_status != Status.COMMITTED:
		ECS.world.remove_entity(grant)
		state.transaction_in_progress = false
		return money_status
	# Wallet commit has no yield, signals or inventory mutation; the validated transfer stays valid.
	var transferred: bool = InventoryService.transfer(grant, actor)
	assert(transferred, "Commerce grant must honor its validated synchronous Inventory contract")
	_record(state, item, quantity, operation_id, cycle.day_index, PurchaseReceipt.Mode.PURCHASE)
	state.transaction_in_progress = false
	return Status.COMMITTED


static func order(actor: Entity, item: DEF_InventoryItem, quantity: int, operation_id: StringName) -> Status:
	var state: C_Commerce = current()
	var cycle: C_DayCycle = DayPhaseService.current()
	var valid: Status = _validate(state, cycle, item, quantity, operation_id, PurchaseReceipt.Mode.ORDER)
	if valid != Status.COMMITTED:
		return valid
	if cycle.phase not in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.EVENING]:
		return Status.WRONG_PHASE
	if not GrabService.holder_available(actor) or actor.has_component(C_Death):
		return Status.INVALID
	state.transaction_in_progress = true
	var money_status: Status = _pay(item, quantity, operation_id, cycle.day_index)
	if money_status != Status.COMMITTED:
		state.transaction_in_progress = false
		return money_status
	var delivery: PendingDelivery = PendingDelivery.new()
	delivery.delivery_id = operation_id
	delivery.item = item
	delivery.quantity = quantity
	delivery.ordered_day = cycle.day_index
	delivery.delivery_day = cycle.day_index + 1
	state.pending_deliveries.append(delivery)
	_record(state, item, quantity, operation_id, cycle.day_index, PurchaseReceipt.Mode.ORDER)
	state.transaction_in_progress = false
	return Status.COMMITTED


static func _validate(state: C_Commerce, cycle: C_DayCycle, item: DEF_InventoryItem, quantity: int, operation_id: StringName, mode: PurchaseReceipt.Mode) -> Status:
	if state == null or cycle == null or state.transaction_in_progress or operation_id.is_empty() or item == null or item.key.is_empty() or quantity < 1 or quantity > item.maximum_stack or item.market_price < 0 or item.market_price > WalletService.MAX_AMOUNT or quantity * item.market_price > WalletService.MAX_AMOUNT:
		return Status.INVALID
	if item not in state.catalog:
		return Status.INVALID
	for receipt: PurchaseReceipt in state.receipts:
		if receipt.operation_id == operation_id:
			return Status.DUPLICATE if receipt.item_key == item.key and receipt.quantity == quantity and receipt.mode == mode else Status.CONFLICT
	return Status.COMMITTED


static func _pay(item: DEF_InventoryItem, quantity: int, operation_id: StringName, day_index: int) -> Status:
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = StringName(WALLET_PREFIX + String(operation_id))
	operation.reason = MoneyOperation.Reason.PURCHASE
	operation.amount = item.market_price * quantity
	operation.day_index = day_index
	match WalletService.submit(operation):
		WalletService.Status.COMMITTED:
			return Status.COMMITTED
		WalletService.Status.INSUFFICIENT_FUNDS:
			return Status.INSUFFICIENT_FUNDS
		WalletService.Status.DUPLICATE, WalletService.Status.CONFLICT:
			return Status.CONFLICT
	return Status.INVALID


static func _record(state: C_Commerce, item: DEF_InventoryItem, quantity: int, operation_id: StringName, day_index: int, mode: PurchaseReceipt.Mode) -> void:
	var receipt: PurchaseReceipt = PurchaseReceipt.new()
	receipt.operation_id = operation_id
	receipt.mode = mode
	receipt.item_key = item.key
	receipt.quantity = quantity
	receipt.total_price = item.market_price * quantity
	receipt.day_index = day_index
	state.receipts.append(receipt)
