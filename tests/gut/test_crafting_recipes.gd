extends GutTest
## Чистые exact/complexity/quantity и реальные immutable prototype Definitions.

const PROFILE: DEF_CraftingProfile = preload(
	"res://content/domains/commerce/definitions/def_crafting_shy_prototype.tres"
)
const TOY: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_toy_block.tres"
)


#region Материалы и каталог
func _material_input(
	requirement: CraftingIngredient,
	id: String,
	quantity: int = 1,
) -> CraftingInput:
	var result: CraftingInput = CraftingInput.new()
	result.entity_id = id
	result.definition = requirement.definition
	result.quantity = quantity
	result.full_blood = requirement.require_full_blood
	return result


func _recipe_copy(source: DEF_CraftingRecipe) -> DEF_CraftingRecipe:
	var result: DEF_CraftingRecipe = source.duplicate() as DEF_CraftingRecipe
	result.ingredients = []
	for ingredient: CraftingIngredient in source.ingredients:
		result.ingredients.append(ingredient.duplicate() as CraftingIngredient)
	return result


func test_complex_recipe_wins_before_ten_simple_without_double_consumption() -> void:
	var complex: DEF_CraftingRecipe = PROFILE.recipes[0]
	var inputs: Array[CraftingInput] = [
		_material_input(complex.ingredients[0], "bones", 10),
		_material_input(complex.ingredients[1], "chain"),
		_material_input(complex.ingredients[2], "blood"),
	]
	var result: CraftingPlan = CraftingRecipeRules.plan(inputs, PROFILE.recipes)
	assert_true(result.reason.is_empty())
	assert_eq(result.recipes.size(), 10)
	assert_eq(result.recipes[0], complex)
	for index: int in range(1, result.recipes.size()):
		assert_eq(result.recipes[index], PROFILE.recipes[1])
	assert_true(result.gifts.is_empty())
	assert_eq(inputs[0].quantity, 10, "The pure plan never consumes its input DTOs")


func test_exact_entire_remainder_precedes_higher_complexity_subset() -> void:
	var complex: DEF_CraftingRecipe = PROFILE.recipes[0]
	var exact: DEF_CraftingRecipe = _recipe_copy(complex)
	exact.key = &"test/whole_set"
	exact.complexity = 1
	exact.ingredients[0].quantity = 2
	var inputs: Array[CraftingInput] = [
		_material_input(complex.ingredients[2], "blood"),
		_material_input(complex.ingredients[0], "bones", 2),
		_material_input(complex.ingredients[1], "chain"),
	]
	var recipes: Array[DEF_CraftingRecipe] = [complex, exact, PROFILE.recipes[1]]
	var result: CraftingPlan = CraftingRecipeRules.plan(inputs, recipes)
	assert_eq(result.recipes.size(), 1)
	assert_eq(result.recipes[0], exact)
	assert_true(result.gifts.is_empty())


func test_incomplete_complex_does_not_steal_simple_and_leftovers_are_gifts() -> void:
	var complex: DEF_CraftingRecipe = PROFILE.recipes[0]
	var inputs: Array[CraftingInput] = [
		_material_input(complex.ingredients[0], "bones", 2),
		_material_input(complex.ingredients[1], "chain"),
	]
	var result: CraftingPlan = CraftingRecipeRules.plan(inputs, PROFILE.recipes)
	assert_eq(result.recipes.size(), 2)
	assert_eq(result.recipes[0], PROFILE.recipes[1])
	assert_eq(result.gifts.size(), 1)
	assert_eq(result.gifts[0].entity_id, "chain")
	assert_eq(result.gifts[0].quantity, 1)


func test_stack_order_and_recipe_array_order_do_not_change_plan() -> void:
	var complex: DEF_CraftingRecipe = PROFILE.recipes[0]
	var inputs: Array[CraftingInput] = [
		_material_input(complex.ingredients[0], "bones/b"),
		_material_input(complex.ingredients[1], "chain"),
		_material_input(complex.ingredients[0], "bones/a"),
		_material_input(complex.ingredients[2], "blood"),
	]
	var first: CraftingPlan = CraftingRecipeRules.plan(inputs, PROFILE.recipes)
	inputs.reverse()
	var recipes: Array[DEF_CraftingRecipe] = PROFILE.recipes.duplicate()
	recipes.reverse()
	var second: CraftingPlan = CraftingRecipeRules.plan(inputs, recipes)
	assert_eq(first.recipes, second.recipes)
	assert_eq(first.gifts.size(), second.gifts.size())
	assert_eq(first.recipes.size(), 2)
	assert_eq(first.recipes[0], complex)


func test_spent_blood_or_wrong_definition_cannot_complete_chain_clothes() -> void:
	var complex: DEF_CraftingRecipe = PROFILE.recipes[0]
	var blood: CraftingInput = _material_input(complex.ingredients[2], "blood")
	var inputs: Array[CraftingInput] = [
		_material_input(complex.ingredients[0], "bones"),
		_material_input(complex.ingredients[1], "chain"),
		blood,
	]
	blood.full_blood = false
	var spent: CraftingPlan = CraftingRecipeRules.plan(inputs, PROFILE.recipes)
	assert_eq(spent.recipes.size(), 1)
	assert_eq(spent.recipes[0], PROFILE.recipes[1])
	assert_eq(spent.gifts.size(), 2)
	blood.definition = TOY
	blood.full_blood = true
	var wrong: CraftingPlan = CraftingRecipeRules.plan(inputs, PROFILE.recipes)
	assert_eq(wrong.recipes.size(), 1)
	assert_eq(wrong.recipes[0], PROFILE.recipes[1])


func test_authoring_rejects_ambiguous_ranks_zero_consumption_and_duplicate_inputs() -> void:
	var other: DEF_CraftingRecipe = _recipe_copy(PROFILE.recipes[0])
	other.key = &"test/ambiguous"
	var recipes: Array[DEF_CraftingRecipe] = [PROFILE.recipes[0], other]
	assert_false(CraftingRecipeRules.catalog_error(recipes).is_empty())
	other.complexity = 5
	other.ingredients[0].quantity = 0
	assert_false(CraftingRecipeRules.catalog_error(recipes).is_empty())
	var input: CraftingInput = _material_input(PROFILE.recipes[0].ingredients[0], "duplicate")
	var inputs: Array[CraftingInput] = [input, input]
	assert_false(CraftingRecipeRules.plan(inputs, PROFILE.recipes).reason.is_empty())
#endregion
