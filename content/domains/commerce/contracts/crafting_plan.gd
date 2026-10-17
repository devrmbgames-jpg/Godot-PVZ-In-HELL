extends RefCounted
## Чистый результат распознавания; runtime owner фиксирует его только при подтверждении.
class_name CraftingPlan

## Ошибка authoring/input; пустая строка означает валидный расчёт, включая неудачный набор.
var reason: String = ""
## Последовательность полностью удовлетворённых рецептов.
var recipes: Array[DEF_CraftingRecipe] = []
## Оставшиеся положительные количества, передаваемые как подарок.
var gifts: Array[CraftingInput] = []
