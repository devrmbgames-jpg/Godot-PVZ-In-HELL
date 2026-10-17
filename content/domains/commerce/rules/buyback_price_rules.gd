extends RefCounted
## Чистые утверждённые цены Дьявола; расчёт единицы перед количеством исключает дробление стека.
class_name BuybackPriceRules

const PERCENT_BASE: int = 100
const ORDINARY_MIN_PERCENT: int = 30
const ORDINARY_MAX_PERCENT: int = 70
const PREMIUM_PERCENT: int = 150
const PREMIUM_MIN_TYPES: int = 1
const PREMIUM_MAX_TYPES: int = 2


#region Спрос из фактически прибывших типов
## Один выбор на seed/личность/день; входные Definitions и глобальный RNG не меняются.
static func demand_keys(
	profile: DEF_BuybackProfile,
	items: Array[DEF_InventoryItem],
	world_seed: int,
	day: int,
) -> PackedStringArray:
	var candidates: PackedStringArray = []
	for item: DEF_InventoryItem in items:
		if eligible(profile, item) and String(item.key) not in candidates:
			candidates.append(String(item.key))
	candidates.sort()
	var result: PackedStringArray = []
	if candidates.is_empty():
		return result
	var random: RandomNumberGenerator = DecisionRandomRules.generator(
		world_seed,
		String(profile.npc_id),
		day,
		"buyback/premium",
		0,
	)
	var count: int = random.randi_range(
		PREMIUM_MIN_TYPES,
		mini(PREMIUM_MAX_TYPES, candidates.size()),
	)
	for index: int in count:
		var candidate_index: int = random.randi_range(0, candidates.size() - 1)
		result.append(candidates[candidate_index])
		candidates.remove_at(candidate_index)
	return result


## Только реально представимые положительно оценённые предметы входят в повышенный спрос.
static func eligible(profile: DEF_BuybackProfile, item: DEF_InventoryItem) -> bool:
	return (
		item != null and not item.resource_path.is_empty() and not item.key.is_empty()
		and item.market_price > 0 and item.market_price <= WalletService.MAX_AMOUNT
		and premium_price(item.market_price) <= WalletService.MAX_AMOUNT
		and String(item.key) not in profile.rejected_item_keys
		and not item.world_pickup_scene.is_empty()
		and ResourceLoader.exists(item.world_pickup_scene, "PackedScene")
	)
#endregion


#region Обычная и повышенная цена
## Одна целая ставка для типа и дня; счётчики глобального RNG не продвигаются.
static func ordinary_price(
	base_price: int,
	world_seed: int,
	day: int,
	trader_id: StringName,
	item_key: StringName,
) -> int:
	var random: RandomNumberGenerator = DecisionRandomRules.generator(
		world_seed,
		String(trader_id),
		day,
		"buyback/ordinary/" + String(item_key),
		0,
	)
	return unit_price(base_price, random.randi_range(ORDINARY_MIN_PERCENT, ORDINARY_MAX_PERCENT))


## Премиальная цена заменяет обычную; это 150% базы, а не множитель текущей ставки.
static func premium_price(base_price: int) -> int:
	return unit_price(base_price, PREMIUM_PERCENT)


## Сначала округляет цену единицы вниз; некорректная база не становится положительной оценкой.
static func unit_price(base_price: int, percent: int) -> int:
	if base_price <= 0 or percent < 0:
		return 0
	@warning_ignore("integer_division")
	return base_price * percent / PERCENT_BASE
#endregion
