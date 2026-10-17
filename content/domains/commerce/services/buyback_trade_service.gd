extends RefCounted
## Явное подтверждение физической партии: повторная оценка, резерв, штатные деньги и удаление.
class_name BuybackTradeService

enum Status {
	COMMITTED,
	DUPLICATE,
	CHANGED,
	UNAVAILABLE,
	CONFLICT,
}


#region Предложение без продажи
## Новый quote не резервирует и не удаляет товары; один ID принадлежит одному подтверждению.
static func quote(actor: Entity, trader: Entity) -> BuybackQuote:
	var result: BuybackQuote = BuybackQuote.new()
	if not GrabQueries.holder_available(actor) or actor.has_component(C_Death):
		result.reason = "Игрок недоступен"
		return result
	if not EntityAvailability.contains(trader, ECS.world):
		result.reason = "Покупатель недоступен"
		return result
	var container: E_BuybackContainer = BuybackQueries.container_for(trader)
	if container == null:
		result.reason = "Контейнер покупателя не найден"
		return result
	var state: C_Buyback = container.get_component(C_Buyback) as C_Buyback
	var cycle: C_DayCycle = DayPhaseQueries.current()
	result.reason = BuybackQueries.unavailable_reason(state, trader, cycle)
	if not result.reason.is_empty():
		return result
	if CommerceService.current() == null:
		result.reason = "Расчёт недоступен"
		return result
	BuybackMarketService.prepare_fixed(state, cycle.day_index)
	result = _evaluate(container, state, trader, cycle.day_index)
	if result.amount > 0:
		result.operation_id = CommerceService.next_id("buyback/" + container.id)
	return result


static func _evaluate(
	container: E_BuybackContainer,
	state: C_Buyback,
	trader: Entity,
	day: int,
	reserved: bool = false,
) -> BuybackQuote:
	var result: BuybackQuote = BuybackQuote.new()
	result.container_reference = weakref(container)
	result.state = state
	result.day_index = day
	result.supply_batch_id = state.supply_batch_id
	result.trader_id = trader.id
	for key: String in state.premium_item_keys:
		for price: BuybackItemPrice in state.prices:
			if String(price.definition.key) != key:
				continue
			var remaining: int = 0 if key in state.premium_spent_keys else 1
			result.market_lines.append(
				"%s · спрос %d · осталось %d из 1"
				% [price.definition.display_name, price.premium_price, remaining]
			)
	var composition: Array = []
	var accepted: Array = []
	var premium_used: PackedStringArray = state.premium_spent_keys.duplicate()
	var bodies: Array[RigidBody3D] = container.bodies()
	bodies.sort_custom(
		func(first: RigidBody3D, second: RigidBody3D) -> bool:
			var first_entity: Entity = first as Node as Entity
			var second_entity: Entity = second as Node as Entity
			var first_key: String = (
				first_entity.id
				if first_entity != null
				else str(first.get_instance_id())
			)
			var second_key: String = (
				second_entity.id
				if second_entity != null
				else str(second.get_instance_id())
			)
			return first_key < second_key,
	)
	for body: RigidBody3D in bodies:
		var item: Entity = body as Node as Entity
		if item == null:
			# Runtime ID участвует только в ephemeral композиции; в receipt он не записывается.
			composition.append([body.get_instance_id(), "unpriced"])
			result.rejected.append(String(body.name) + " · нет авторской оценки")
			continue
		var stack: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		var reason: String = BuybackQueries.item_reason(
			container,
			item,
			container if reserved else null,
		)
		var title: String = (
			stack.definition.display_name
			if (stack != null and stack.definition != null)
			else String(item.name)
		)
		if not reason.is_empty():
			composition.append([item.id, reason])
			result.rejected.append(title + " · " + reason)
			continue
		var price: BuybackItemPrice = BuybackMarketService.ensure_price(state, stack.definition)
		if price == null:
			composition.append([item.id, "unpriced"])
			result.rejected.append(title + " · нет закупочной цены")
			continue
		var line: BuybackSaleItem = BuybackSaleItem.new()
		line.entity_id = item.id
		line.definition = stack.definition
		line.quantity = stack.quantity
		line.source_package_id = stack.source_package_id
		line.source_history_id = stack.source_history_id
		var key: String = String(stack.definition.key)
		if key in state.premium_item_keys and key not in premium_used:
			line.premium_quantity = 1
			premium_used.append(key)
		line.amount = (
			price.ordinary_price * (line.quantity - line.premium_quantity)
			+ price.premium_price * line.premium_quantity
		)
		if line.amount <= 0 or line.amount > WalletService.MAX_AMOUNT:
			composition.append([item.id, "no_value"])
			result.rejected.append(title + " · не имеет выкупной стоимости")
			continue
		var payload: Array = [
			line.entity_id,
			line.definition.resource_path,
			line.quantity,
			line.premium_quantity,
			line.amount,
			line.source_package_id,
			line.source_history_id,
		]
		accepted.append(payload)
		composition.append(payload)
		result.items.append(line)
		result.amount += line.amount
	result.signature = var_to_str([day, state.supply_batch_id, trader.id, accepted])
	result.composition_signature = var_to_str(composition)
	if result.amount > WalletService.MAX_AMOUNT:
		result.reason = "Сумма превышает предел расчёта"
	return result
#endregion


#region Синхронное подтверждение
## CHANGED требует нового quote и нового нажатия; изменившаяся сумма не принимается молча.
## Деньги/receipt фиксируются до структурных callbacks удаления, под общим snapshot guard.
static func confirm(actor: Entity, trader: Entity, offer: BuybackQuote) -> Status:
	if offer == null or offer.container_reference == null or offer.operation_id.is_empty():
		return Status.UNAVAILABLE
	var world: World = ECS.world
	var container: E_BuybackContainer = offer.container_reference.get_ref() as E_BuybackContainer
	if (
		not EntityAvailability.contains(container, world)
		or container.get_component(C_Buyback) != offer.state
	):
		return Status.UNAVAILABLE
	var state: C_Buyback = offer.state
	var commerce: C_Commerce = CommerceService.current()
	if commerce == null or commerce.transaction_in_progress:
		return Status.UNAVAILABLE
	for previous: BuybackSale in commerce.buyback_sales:
		if previous.operation_id != offer.operation_id:
			continue
		if previous.signature != offer.signature:
			return Status.CONFLICT
		if not previous.settled:
			return Status.UNAVAILABLE
		for line: BuybackSaleItem in previous.items:
			if not line.removed:
				return Status.UNAVAILABLE
		return Status.DUPLICATE
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if (
		commerce.transaction_in_progress
		or not GrabQueries.holder_available(actor) or actor.has_component(C_Death)
		or not EntityAvailability.contains(trader, world) or trader.id != offer.trader_id
		or BuybackQueries.container_for(trader) != container
		or not BuybackQueries.unavailable_reason(state, trader, cycle).is_empty()
	):
		return Status.UNAVAILABLE
	if cycle.day_index != offer.day_index or state.supply_batch_id != offer.supply_batch_id:
		return Status.CHANGED
	var fresh: BuybackQuote = _evaluate(container, state, trader, cycle.day_index)
	if not _same_offer(offer, fresh):
		return Status.CHANGED
	commerce.transaction_in_progress = true
	state.transaction_in_progress = true
	var reserved: Array[WeakRef] = []
	# Callback не переписывает исходное UI-предложение внутри принятой транзакции.
	fresh.operation_id = offer.operation_id
	var status: Status = _commit(world, actor, trader, container, commerce, state, fresh, reserved)
	# Резерв живёт только внутри подтверждения, включая отказ до оплаты.
	for reference: WeakRef in reserved:
		if not is_instance_valid(world):
			break
		var item: Entity = reference.get_ref() as Entity
		if not is_instance_valid(item) or not world.entity_to_archetype.has(item):
			continue
		for link: Relationship in item.relationships.duplicate():
			if link.relation is R_BuybackReserved and link.target == container:
				item.remove_relationship(link)
	state.transaction_in_progress = false
	commerce.transaction_in_progress = false
	if (
		status == Status.COMMITTED and ECS.world == world
		and EntityAvailability.contains(container, world)
		and container.get_component(C_Buyback) == state
	):
		world.emit_event(BuybackSale.EVENT, container, fresh.operation_id)
	return status


static func _commit(
	world: World,
	actor: Entity,
	trader: Entity,
	container: E_BuybackContainer,
	commerce: C_Commerce,
	state: C_Buyback,
	offer: BuybackQuote,
	reserved: Array[WeakRef],
) -> Status:
	for line: BuybackSaleItem in offer.items:
		var item: Entity = world.entity_id_registry.get(line.entity_id) as Entity
		if not EntityAvailability.contains(item, world):
			return Status.CHANGED
		reserved.append(weakref(item))
		item.add_relationship(Relationship.new(R_BuybackReserved.new(), container))
		if (
			not is_instance_valid(world) or ECS.world != world
			or not EntityAvailability.contains(container, world)
			or container.get_component(C_Buyback) != state or CommerceService.current() != commerce
		):
			return Status.UNAVAILABLE
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if (
		cycle == null or cycle.day_index != offer.day_index or cycle.phase == C_DayCycle.Phase.NIGHT
		or (state.profile.open_phases & (1 << cycle.phase)) == 0
		or not GrabQueries.holder_available(actor) or not GrabQueries.holder_available(trader)
		or trader.has_component(C_Death) or BuybackQueries.container_for(trader) != container
	):
		return Status.UNAVAILABLE
	var fresh: BuybackQuote = _evaluate(container, state, trader, cycle.day_index, true)
	if not _same_offer(offer, fresh):
		return Status.CHANGED
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = offer.operation_id
	operation.reason = MoneyOperation.Reason.NPC_BUYBACK
	operation.amount = fresh.amount
	operation.day_index = cycle.day_index
	operation.note = "Скупка · " + state.profile.display_name
	var wallet: C_Wallet = WalletService.current()
	var payment_preview: WalletService.Status = WalletService.apply(
		WalletService.snapshot(wallet),
		operation,
		cycle.day_index,
	)
	if payment_preview != WalletService.Status.COMMITTED:
		return Status.CONFLICT
	var sale: BuybackSale = BuybackSale.new()
	sale.operation_id = offer.operation_id
	sale.trader_id = offer.trader_id
	sale.buyer_npc_id = state.profile.npc_id
	sale.container_id = container.id
	sale.day_index = offer.day_index
	sale.supply_batch_id = offer.supply_batch_id
	sale.signature = offer.signature
	sale.amount = fresh.amount
	for line: BuybackSaleItem in fresh.items:
		sale.items.append(line.duplicate() as BuybackSaleItem)
	commerce.buyback_sales.append(sale)
	var payment: WalletService.Status = WalletService.apply(wallet, operation, cycle.day_index)
	if payment != WalletService.Status.COMMITTED:
		commerce.buyback_sales.erase(sale)
		return Status.CONFLICT
	sale.settled = true
	for line: BuybackSaleItem in sale.items:
		if line.premium_quantity > 0:
			state.premium_spent_keys.append(String(line.definition.key))
	# Retire the captured endpoints: callbacks may reuse IDs or switch the current World.
	# A destroyed World purges its own entities; never resolve replacements in another World.
	for index: int in sale.items.size():
		var line: BuybackSaleItem = sale.items[index]
		line.removed = true
		if not is_instance_valid(world):
			continue
		var item: Entity = reserved[index].get_ref() as Entity
		if is_instance_valid(item) and world.entity_to_archetype.has(item):
			world.remove_entity(item)
	return Status.COMMITTED


static func _same_offer(expected: BuybackQuote, current: BuybackQuote) -> bool:
	return (
		current.reason.is_empty() and current.amount > 0
		and current.amount == expected.amount and current.signature == expected.signature
		and current.composition_signature == expected.composition_signature
	)
#endregion
