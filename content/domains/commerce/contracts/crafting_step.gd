extends Resource
## Исторический шаг принятой партии; authored рецепт больше не владеет его обещанием.
class_name CraftingStep

## Закрытый контракт расхода и результата одного выбранного рецепта.
const SAVE_FIELDS: Array[String] = ["recipe_key", "ingredients", "output", "output_quantity"]

## Принятый авторский ID для истории; загрузка не ищет по нему текущий рецепт.
@export var recipe_key: StringName = &""
## Копии требований на момент приёма, с прежними количествами и условиями пригодности.
@export var ingredients: Array[CraftingIngredient] = []
## Принятое определение физического изделия.
@export var output: DEF_InventoryItem = null
## Принятое число отдельных изделий за этот шаг.
@export var output_quantity: int = 0


#region Исторический расход
## Копирует поля рецепта и его требований, сохраняя идентичность типов материалов.
static func capture(recipe: DEF_CraftingRecipe) -> CraftingStep:
	var result: CraftingStep = CraftingStep.new()
	result.recipe_key = recipe.key
	result.output = recipe.output
	result.output_quantity = recipe.output_quantity
	for ingredient: CraftingIngredient in recipe.ingredients:
		result.ingredients.append(ingredient.duplicate() as CraftingIngredient)
	return result


## Временное описание только этого принятого шага для общего алгоритма расхода.
func recipe() -> DEF_CraftingRecipe:
	var result: DEF_CraftingRecipe = DEF_CraftingRecipe.new()
	result.key = recipe_key
	result.ingredients = ingredients
	result.output = output
	result.output_quantity = output_quantity
	return result
#endregion
