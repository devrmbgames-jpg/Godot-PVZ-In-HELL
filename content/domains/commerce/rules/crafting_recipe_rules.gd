extends RefCounted
## Чистое распознавание конечного набора: exact first, затем сложность/приоритет и остаток.
class_name CraftingRecipeRules


#region Проверка authoring и входа
## Коллизия рангов отвергается явно: порядок .tres/Array не выбирает победивший рецепт.
static func catalog_error(recipes: Array[DEF_CraftingRecipe]) -> String:
	if recipes.is_empty():
		return "Каталог рецептов пуст"
	var keys: Array[StringName] = []
	var ranks: PackedStringArray = []
	for recipe: DEF_CraftingRecipe in recipes:
		if recipe == null or recipe.key.is_empty() or recipe.key in keys:
			return "Повторяющийся или пустой ID рецепта"
		keys.append(recipe.key)
		if recipe.ingredients.is_empty() or recipe.output == null or recipe.output_quantity < 1:
			return "Рецепт должен расходовать материалы и создавать результат"
		if recipe.output_quantity > 99 or recipe.complexity < 0:
			return "Некорректное количество или сложность"
		if recipe.output.world_pickup_scene.is_empty():
			return "У результата нет физической сцены"
		var rank: String = "%d/%d" % [recipe.complexity, recipe.priority]
		if rank in ranks:
			return "Неоднозначные сложность и приоритет рецептов"
		ranks.append(rank)
		var ingredients: Array[StringName] = []
		for requirement: CraftingIngredient in recipe.ingredients:
			if (
				requirement == null or requirement.definition == null
				or requirement.quantity < 1 or requirement.quantity > 99
				or requirement.definition.key.is_empty() or requirement.definition.key
				in ingredients
			):
				return "Некорректный или повторяющийся материал"
			if requirement.require_full_blood and requirement.definition.key != &"blood_flask":
				return "Полная кровь требует точного определения колбы крови"
			ingredients.append(requirement.definition.key)
	return ""
#endregion


#region Распознавание одной полной передачи
## Входы/Definitions не меняются. Каждый успех уменьшает положительный остаток, цикл конечен.
static func plan(inputs: Array[CraftingInput], recipes: Array[DEF_CraftingRecipe]) -> CraftingPlan:
	var result: CraftingPlan = CraftingPlan.new()
	result.reason = catalog_error(recipes)
	if not result.reason.is_empty():
		return result
	var remaining: Array[CraftingInput] = []
	var ids: PackedStringArray = []
	for item: CraftingInput in inputs:
		if (
			item == null or item.entity_id.is_empty() or item.entity_id in ids
			or item.definition == null or item.quantity < 1
			or item.quantity > item.definition.maximum_stack
		):
			result.reason = "Некорректный физический состав"
			return result
		ids.append(item.entity_id)
		remaining.append(item.duplicate() as CraftingInput)
	remaining.sort_custom(
		func(first: CraftingInput, second: CraftingInput) -> bool:
			return first.entity_id < second.entity_id,
	)
	var ordered: Array[DEF_CraftingRecipe] = recipes.duplicate()
	ordered.sort_custom(
		func(first: DEF_CraftingRecipe, second: DEF_CraftingRecipe) -> bool:
			if first.complexity != second.complexity:
				return first.complexity > second.complexity
			return first.priority > second.priority,
	)
	while true:
		var chosen: DEF_CraftingRecipe = null
		var allocation: PackedInt32Array = []
		for exact: bool in [true, false]:
			for recipe: DEF_CraftingRecipe in ordered:
				var candidate: PackedInt32Array = _allocate(remaining, recipe, exact)
				if not candidate.is_empty():
					chosen = recipe
					allocation = candidate
					break
			if chosen != null:
				break
		if chosen == null:
			break
		result.recipes.append(chosen)
		for index: int in remaining.size():
			remaining[index].quantity -= allocation[index]
	for item: CraftingInput in remaining:
		if item.quantity > 0:
			result.gifts.append(item)
	return result


## Проверяет уже выбранные исторические шаги; текущий каталог и его ранги не участвуют.
static func replay(inputs: Array[CraftingInput], steps: Array[CraftingStep]) -> CraftingPlan:
	var result: CraftingPlan = CraftingPlan.new()
	var remaining: Array[CraftingInput] = []
	for item: CraftingInput in inputs:
		remaining.append(item.duplicate() as CraftingInput)
	for step: CraftingStep in steps:
		if step == null:
			result.reason = "Отсутствует принятый шаг"
			return result
		var recipe: DEF_CraftingRecipe = step.recipe()
		result.reason = catalog_error([recipe])
		if not result.reason.is_empty():
			return result
		var allocation: PackedInt32Array = _allocate(remaining, recipe, false)
		if allocation.is_empty():
			result.reason = "Принятый шаг не обеспечен материалами"
			return result
		for index: int in remaining.size():
			remaining[index].quantity -= allocation[index]
	for item: CraftingInput in remaining:
		if item.quantity > 0:
			result.gifts.append(item)
	return result


static func _allocate(
	remaining: Array[CraftingInput],
	recipe: DEF_CraftingRecipe,
	exact: bool,
) -> PackedInt32Array:
	var allocation: PackedInt32Array = []
	allocation.resize(remaining.size())
	var total: int = 0
	for requirement: CraftingIngredient in recipe.ingredients:
		var needed: int = requirement.quantity
		for index: int in remaining.size():
			var item: CraftingInput = remaining[index]
			if (
				item.definition != requirement.definition
				or (requirement.require_intact and not item.intact)
				or (requirement.require_full_blood and not item.full_blood)
			):
				continue
			var count: int = mini(needed, item.quantity)
			allocation[index] += count
			needed -= count
			total += count
			if needed == 0:
				break
		if needed > 0:
			return []
	if exact:
		var available: int = 0
		for item: CraftingInput in remaining:
			available += item.quantity
		if total != available:
			return []
	return allocation
#endregion


#region Каноническая идентичность принятого состава
## Removed и будущие результаты не переписывают подписанные факты передачи.
static func signature(
	container_id: String,
	day: int,
	profile: DEF_CraftingProfile,
	grace_was_used: bool,
	inputs: Array[CraftingInput],
) -> String:
	var payload: Array = []
	for item: CraftingInput in inputs:
		payload.append(
			[
				item.entity_id,
				item.definition.resource_path,
				item.quantity,
				item.source_package_id,
				item.source_history_id,
				item.intact,
				item.full_blood,
			]
		)
	return var_to_str([container_id, day, profile.resource_path, grace_was_used, payload])
#endregion
