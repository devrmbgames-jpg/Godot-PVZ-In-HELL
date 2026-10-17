extends RefCounted
## Явные операции одного терминала Ангела; общий кошелёк не делает очередь общей с ПВЗ.
class_name AngelFurnitureService

enum Status {
	COMMITTED,
	DUPLICATE,
	CHANGED,
	UNAVAILABLE,
	INSUFFICIENT_FUNDS,
}


#region Доступ и предложение без оплаты
## Доступность автоматической точки не зависит от жизни NPC или состояния ПВЗ.
static func available(terminal: Entity, actor: Entity) -> bool:
	if (
		not EntityAvailability.contains(terminal, ECS.world)
		or not EntityAvailability.contains(actor, ECS.world) or not terminal.enabled
		or not terminal is E_Terminal or not actor.enabled
		or actor.has_component(C_Death) or not ECS.world.get_parent() is Node3D
	):
		return false
	var state: C_AngelOrders = terminal.get_component(C_AngelOrders) as C_AngelOrders
	var receiving: C_OrderReceiving = terminal.get_component(C_OrderReceiving) as C_OrderReceiving
	var cycle: C_DayCycle = DayPhaseQueries.current()
	return (
		state != null and state.profile != null and receiving != null
		and state.next_request > 0 and not state.profile.resource_path.is_empty()
		and not state.transaction_in_progress and not state.profile.receiving_id.is_empty()
		and not state.profile.receiving_hint.is_empty() and cycle != null
		and cycle.phase != C_DayCycle.Phase.NIGHT and WalletService.current() != null
	)


## Резервирует только ID запроса; отмена не меняет баланс, очередь или физический мир.
static func quote(actor: Entity, terminal: Entity, item: DEF_InventoryItem) -> AngelFurnitureQuote:
	var offer: AngelFurnitureQuote = AngelFurnitureQuote.new()
	if not available(terminal, actor):
		offer.reason = "Терминал сейчас недоступен."
		return offer

	offer.world = weakref(ECS.world)
	offer.actor = weakref(actor)
	offer.terminal = weakref(terminal)
	offer.state = terminal.get_component(C_AngelOrders) as C_AngelOrders
	var request_id: StringName = StringName("angel/%s/%d" % [terminal.id, offer.state.next_request])
	offer.state.next_request += 1
	offer.order = _new_order(terminal, offer.state, item, request_id)
	if offer.order == null or not _can_place(terminal, item, offer.order.output_id):
		offer.reason = "Эта мебель сейчас не подходит для площадки. Освободите место."
	return offer


static func _new_order(
	terminal: Entity,
	state: C_AngelOrders,
	item: DEF_InventoryItem,
	request_id: StringName,
) -> AngelFurnitureOrder:
	if (
		item == null or item.resource_path.is_empty() or item not in state.profile.catalog
		or item.kind != DEF_InventoryItem.Kind.FURNITURE
		or item.market_price < 0 or item.market_price > WalletService.MAX_AMOUNT
		or not OrderDeliveryService.can_fulfill_definition(item)
	):
		return null
	var record: AngelFurnitureOrder = AngelFurnitureOrder.new()
	record.operation_id = request_id
	record.terminal_id = terminal.id
	record.receiving_id = state.profile.receiving_id
	record.receiving_hint = state.profile.receiving_hint
	record.item = item
	record.total_price = item.market_price
	record.ordered_day = DayPhaseQueries.current().day_index
	record.ready_day = record.ordered_day + 1
	record.output_id = "angel-order/%s" % request_id
	return record


static func _can_place(terminal: Entity, item: DEF_InventoryItem, output_id: String) -> bool:
	var receiving: C_OrderReceiving = terminal.get_component(C_OrderReceiving) as C_OrderReceiving
	var previous_blocked: bool = receiving.blocked
	var proposal: PreparedFurniture = OrderDeliveryService.prepare_furniture(
		terminal,
		receiving,
		item,
		output_id,
		ECS.world.get_parent() as Node3D,
	)
	receiving.blocked = previous_blocked
	if proposal == null:
		return false
	proposal.entity.free()
	return true
#endregion


#region Однократная оплата
## Повтор принятого предложения читает собственный чек; нынешний каталог не переписывает историю.
static func confirm(actor: Entity, offer: AngelFurnitureQuote) -> Status:
	if (
		offer == null or not offer.reason.is_empty() or offer.order == null or offer.world == null
		or offer.world.get_ref() != ECS.world or offer.actor.get_ref() != actor
	):
		return Status.UNAVAILABLE
	var terminal: Entity = offer.terminal.get_ref() as Entity
	if (
		not EntityAvailability.contains(terminal, ECS.world)
		or terminal.get_component(C_AngelOrders) != offer.state
		or offer.state.transaction_in_progress
	):
		return Status.UNAVAILABLE
	for previous: AngelFurnitureOrder in offer.state.orders:
		if previous.operation_id == offer.order.operation_id:
			return Status.DUPLICATE if _same_promise(previous, offer.order) else Status.CHANGED
	if not available(terminal, actor):
		return Status.UNAVAILABLE
	var record: AngelFurnitureOrder = _new_order(
		terminal,
		offer.state,
		offer.order.item,
		offer.order.operation_id,
	)
	if record == null or not _same_promise(record, offer.order):
		return Status.CHANGED
	if not _can_place(terminal, record.item, record.output_id):
		return Status.UNAVAILABLE

	var state: C_AngelOrders = offer.state
	state.transaction_in_progress = true
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = record.operation_id
	operation.reason = MoneyOperation.Reason.PURCHASE
	operation.amount = record.total_price
	operation.day_index = record.ordered_day
	var result: WalletService.Status = WalletService.submit(operation)
	if result != WalletService.Status.COMMITTED:
		state.transaction_in_progress = false
		return (
			Status.INSUFFICIENT_FUNDS
			if result == WalletService.Status.INSUFFICIENT_FUNDS
			else Status.UNAVAILABLE
		)
	record.paid = true
	state.orders.append(record)
	state.transaction_in_progress = false
	var receiving: C_OrderReceiving = terminal.get_component(C_OrderReceiving) as C_OrderReceiving
	receiving.exhausted = false
	return Status.COMMITTED


static func _same_promise(left: AngelFurnitureOrder, right: AngelFurnitureOrder) -> bool:
	return (
		left.operation_id == right.operation_id and left.terminal_id == right.terminal_id
		and left.receiving_id == right.receiving_id and left.receiving_hint == right.receiving_hint
		and left.item == right.item and left.quantity == right.quantity
		and left.total_price == right.total_price and left.ordered_day == right.ordered_day
		and left.ready_day == right.ready_day and left.output_id == right.output_id
	)
#endregion
