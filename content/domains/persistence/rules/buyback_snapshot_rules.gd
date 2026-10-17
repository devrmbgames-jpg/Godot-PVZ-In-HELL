extends RefCounted
## Проверяет дневной рынок, происхождение и оплаченные продажи до изменения live World.
class_name BuybackSnapshotRules


#region Decoded snapshot contracts
## Данные уже декодированы закрытым codec; live Entities и текущий ECS.world не читаются.
static func valid(
	components: Dictionary[String, Dictionary],
	records: Dictionary[String, Dictionary],
) -> bool:
	var wallet: C_Wallet = null
	var commerce: C_Commerce = null
	var cycle: C_DayCycle = null
	var arrivals: Dictionary[String, PackageRegistrationRecord] = { }
	var states: Dictionary[String, C_Buyback] = { }
	for key: String in components:
		var types: Dictionary = components[key]
		if types.has(C_Wallet):
			if wallet != null:
				return false
			wallet = types[C_Wallet] as C_Wallet
		if types.has(C_Commerce):
			if commerce != null:
				return false
			commerce = types[C_Commerce] as C_Commerce
		if types.has(C_DayCycle):
			cycle = types[C_DayCycle] as C_DayCycle
		if types.has(C_PackageLedger):
			for arrival: PackageRegistrationRecord in (
				types[C_PackageLedger] as C_PackageLedger
			).records:
				if arrival == null or arrivals.has(arrival.package_id):
					return false
				arrivals[arrival.package_id] = arrival
		if types.has(C_Buyback):
			states[key] = types[C_Buyback] as C_Buyback

	for key: String in components:
		var types: Dictionary = components[key]
		if types.has(C_InventoryItem):
			var stack: C_InventoryItem = types[C_InventoryItem] as C_InventoryItem
			if not _origin_valid(stack.source_package_id, stack.source_history_id, arrivals):
				return false
		if types.has(C_LootDrops):
			for pending: PendingLootDrop in (types[C_LootDrops] as C_LootDrops).pending:
				if (
					pending == null
					or not _origin_valid(pending.package_id, pending.source_history_id, arrivals)
				):
					return false
	var buyers: Array[StringName] = []
	for key: String in states:
		if states[key].profile == null or states[key].profile.npc_id in buyers:
			return false
		buyers.append(states[key].profile.npc_id)
		if cycle == null or not _market_valid(states[key], cycle, arrivals):
			return false
	if commerce == null:
		return states.is_empty()
	if wallet == null:
		return commerce.buyback_sales.is_empty() and _spent_matches(states, commerce)
	if cycle == null:
		return false

	var sales: Dictionary[StringName, BuybackSale] = { }
	var sold: Dictionary[String, bool] = { }
	for sale: BuybackSale in commerce.buyback_sales:
		if not _sale_valid(sale, cycle.day_index, arrivals, records, sold):
			return false
		if sales.has(sale.operation_id):
			return false
		sales[sale.operation_id] = sale
	var paid: Dictionary[StringName, bool] = { }
	for operation: MoneyOperation in wallet.operations:
		if operation == null:
			return false
		if operation.reason != MoneyOperation.Reason.NPC_BUYBACK:
			if sales.has(operation.operation_id):
				return false
			continue
		var sale: BuybackSale = sales.get(operation.operation_id) as BuybackSale
		if (
			sale == null or paid.has(operation.operation_id) or operation.amount != sale.amount
			or operation.day_index != sale.day_index or not operation.settlement_id.is_empty()
		):
			return false
		paid[operation.operation_id] = true
	return paid.size() == sales.size() and _spent_matches(states, commerce)


static func _origin_valid(
	package_id: String,
	history_id: String,
	arrivals: Dictionary[String, PackageRegistrationRecord],
) -> bool:
	if package_id.is_empty():
		return history_id.is_empty()
	var arrival: PackageRegistrationRecord = arrivals.get(package_id) as PackageRegistrationRecord
	# Изолированная/ещё не учтённая коробка сохраняет ID без выдуманного архивного факта.
	# У известного arrival отсутствие history уже не допускается.
	if history_id.is_empty():
		return arrival == null
	return (
		not history_id.is_empty() and PackageHistoryId.parse(history_id) != null
		and arrival != null and arrival.history_id == history_id
	)


static func _market_valid(
	state: C_Buyback,
	cycle: C_DayCycle,
	arrivals: Dictionary[String, PackageRegistrationRecord],
) -> bool:
	var profile: DEF_BuybackProfile = state.profile
	if profile == null or profile.resource_path.is_empty() or profile.npc_id.is_empty():
		return false
	if state.price_day < 0 or state.price_day > cycle.day_index:
		return false
	if state.price_day == 0:
		return (
			state.price_seed == 0 and state.supply_batch_id.is_empty()
			and state.source_package_ids.is_empty() and state.premium_item_keys.is_empty()
			and state.premium_spent_keys.is_empty() and state.prices.is_empty()
		)
	var source_keys: PackedStringArray = []
	var source_items: Array[DEF_InventoryItem] = []
	var packages: PackedStringArray = []
	for package_id: String in state.source_package_ids:
		var arrival: PackageRegistrationRecord = arrivals.get(package_id)
		if (arrival == null or package_id in packages or arrival.received_day != state.price_day):
			return false
		packages.append(package_id)
		if arrival.ordered_item != null and arrival.ordered_quantity > 0:
			source_keys.append(String(arrival.ordered_item.key))
			source_items.append(arrival.ordered_item)
	if profile.pricing == DEF_BuybackProfile.Pricing.FIXED:
		if (
			not packages.is_empty() or not state.supply_batch_id.is_empty()
			or not state.premium_item_keys.is_empty() or not state.premium_spent_keys.is_empty()
		):
			return false
	else:
		if state.supply_batch_id.is_empty() or state.price_seed != cycle.clock.world_seed:
			return false
		if state.premium_item_keys != BuybackPriceRules.demand_keys(
			profile,
			source_items,
			state.price_seed,
			state.price_day,
		):
			return false
	var premium: PackedStringArray = []
	for key: String in state.premium_item_keys:
		if (
			key.is_empty() or key in premium or key not in source_keys
			or key in profile.rejected_item_keys
		):
			return false
		premium.append(key)
	var spent: PackedStringArray = []
	for key: String in state.premium_spent_keys:
		if key not in premium or key in spent:
			return false
		spent.append(key)
	var priced: PackedStringArray = []
	for price: BuybackItemPrice in state.prices:
		if price == null or price.definition == null or price.definition.resource_path.is_empty():
			return false
		var key: String = String(price.definition.key)
		if (
			key.is_empty() or key in priced or key in profile.rejected_item_keys
			or price.base_price < 0 or price.base_price > WalletService.MAX_AMOUNT
			or price.ordinary_price < 0 or price.ordinary_price > WalletService.MAX_AMOUNT
			or price.premium_price < 0 or price.premium_price > WalletService.MAX_AMOUNT
		):
			return false
		priced.append(key)
		if profile.pricing == DEF_BuybackProfile.Pricing.FIXED:
			if (
				not profile.fixed_prices.has(price.definition.key)
				or price.ordinary_price != profile.fixed_prices[price.definition.key]
				or price.premium_price != 0
			):
				return false
		elif (
			price.ordinary_price
			!= BuybackPriceRules.ordinary_price(
				price.base_price,
				state.price_seed,
				state.price_day,
				profile.npc_id,
				price.definition.key,
			)
			or price.premium_price != BuybackPriceRules.premium_price(price.base_price)
		):
			return false
	for key: String in premium:
		if key not in priced:
			return false
	return true
#endregion


#region Settled receipts and exactly-once premium
static func _sale_valid(
	sale: BuybackSale,
	day: int,
	arrivals: Dictionary[String, PackageRegistrationRecord],
	records: Dictionary[String, Dictionary],
	sold: Dictionary[String, bool],
) -> bool:
	if (
		sale == null or sale.operation_id.is_empty() or sale.trader_id.is_empty()
		or sale.buyer_npc_id.is_empty() or sale.container_id.is_empty() or sale.day_index < 1
		or sale.day_index > day or sale.signature.is_empty() or not sale.settled
		or sale.items.is_empty() or sale.amount < 1 or sale.amount > WalletService.MAX_AMOUNT
	):
		return false
	var amount: int = 0
	var payload: Array = []
	for line: BuybackSaleItem in sale.items:
		if (
			line == null or line.entity_id.is_empty() or line.definition == null
			or line.definition.resource_path.is_empty() or not line.removed
			or sold.has(line.entity_id) or records.has(line.entity_id) or line.quantity < 1
			or line.quantity > line.definition.maximum_stack or line.premium_quantity < 0
			or line.premium_quantity > 1 or line.premium_quantity > line.quantity
			or line.amount < 1 or line.amount > WalletService.MAX_AMOUNT
			or not _origin_valid(line.source_package_id, line.source_history_id, arrivals)
		):
			return false
		for record: Dictionary in records.values():
			if String(record.entity_id) == line.entity_id:
				return false
		sold[line.entity_id] = true
		amount += line.amount
		payload.append(
			[
				line.entity_id,
				line.definition.resource_path,
				line.quantity,
				line.premium_quantity,
				line.amount,
				line.source_package_id,
				line.source_history_id,
			]
		)
	return (
		amount == sale.amount
		and sale.signature
		== var_to_str([sale.day_index, sale.supply_batch_id, sale.trader_id, payload])
	)


static func _spent_matches(states: Dictionary[String, C_Buyback], commerce: C_Commerce) -> bool:
	var premium_sales: Dictionary[String, bool] = { }
	for sale: BuybackSale in commerce.buyback_sales:
		if sale == null:
			return false
		for line: BuybackSaleItem in sale.items:
			if line == null:
				return false
			for container_id: String in states:
				var market: C_Buyback = states[container_id]
				if market.profile.npc_id != sale.buyer_npc_id or market.price_day != sale.day_index:
					continue
				if sale.supply_batch_id != market.supply_batch_id:
					return false
				var matched: bool = false
				for price: BuybackItemPrice in market.prices:
					if price.definition != line.definition:
						continue
					matched = true
					if line.amount != (
						price.ordinary_price * (line.quantity - line.premium_quantity)
						+ price.premium_price * line.premium_quantity
					):
						return false
				if (
					not matched
					or (
						line.premium_quantity > 0
						and String(line.definition.key) not in market.premium_item_keys
					)
				):
					return false
			if line.premium_quantity == 0:
				continue
			var key: String = "%s/%d/%s" % [sale.buyer_npc_id, sale.day_index, line.definition.key]
			if premium_sales.has(key):
				return false
			premium_sales[key] = true
	for container_id: String in states:
		var state: C_Buyback = states[container_id]
		for item_key: String in state.premium_item_keys:
			var key: String = "%s/%d/%s" % [state.profile.npc_id, state.price_day, item_key]
			if (item_key in state.premium_spent_keys) != premium_sales.has(key):
				return false
	return true
#endregion
