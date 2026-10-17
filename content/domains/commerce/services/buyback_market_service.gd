extends RefCounted
## Фиксирует прайс одной точки по фактическому завершению поставки, без собственного tick.
class_name BuybackMarketService


#region Явные операции прайса
## Повтор той же/старой поставки не обновляет цену, спрос или premium остаток.
static func accept_supply(state: C_Buyback, fact: ReceivingSupplyCompleted) -> void:
	var profile: DEF_BuybackProfile = state.profile
	assert(profile != null)
	if (
		profile.pricing != DEF_BuybackProfile.Pricing.DEMON_DAILY
		or state.transaction_in_progress or state.price_day >= fact.day_index
	):
		return
	state.price_day = fact.day_index
	state.price_seed = GameTimeQueries.current().world_seed
	state.supply_batch_id = fact.batch_id
	state.source_package_ids = fact.package_ids.duplicate()
	state.premium_item_keys.clear()
	state.premium_spent_keys.clear()
	state.prices.clear()
	state.premium_item_keys = BuybackPriceRules.demand_keys(
		profile,
		fact.items,
		state.price_seed,
		fact.day_index,
	)
	for item: DEF_InventoryItem in fact.items:
		if String(item.key) in state.premium_item_keys:
			ensure_price(state, item)


## Возвращает прежнюю цену типа либо один раз фиксирует её в текущем прайсе.
## Caller сначала проверяет доступность дня/профиля; неизвестный/запрещённый тип не добавляется.
static func ensure_price(state: C_Buyback, item: DEF_InventoryItem) -> BuybackItemPrice:
	for price: BuybackItemPrice in state.prices:
		if price.definition.key == item.key:
			return price
	var profile: DEF_BuybackProfile = state.profile
	if (
		item.resource_path.is_empty() or item.key.is_empty()
		or String(item.key) in profile.rejected_item_keys
		or item.market_price < 0 or item.market_price > WalletService.MAX_AMOUNT
	):
		return null
	var price: BuybackItemPrice = BuybackItemPrice.new()
	price.definition = item
	price.base_price = item.market_price
	if profile.pricing == DEF_BuybackProfile.Pricing.FIXED:
		if not profile.fixed_prices.has(item.key):
			return null
		price.ordinary_price = profile.fixed_prices[item.key]
	else:
		price.ordinary_price = BuybackPriceRules.ordinary_price(
			item.market_price,
			state.price_seed,
			state.price_day,
			profile.npc_id,
			item.key,
		)
		price.premium_price = BuybackPriceRules.premium_price(item.market_price)
	if (
		price.ordinary_price < 0 or price.ordinary_price > WalletService.MAX_AMOUNT
		or price.premium_price > WalletService.MAX_AMOUNT
	):
		return null
	state.prices.append(price)
	return price


## Фиксированная скупка не зависит от утренней поставки; история сделок не очищается.
static func prepare_fixed(state: C_Buyback, day: int) -> void:
	if state.profile.pricing != DEF_BuybackProfile.Pricing.FIXED or state.price_day >= day:
		return
	state.price_day = day
	state.supply_batch_id = ""
	state.source_package_ids.clear()
	state.premium_item_keys.clear()
	state.premium_spent_keys.clear()
	state.prices.clear()
#endregion
