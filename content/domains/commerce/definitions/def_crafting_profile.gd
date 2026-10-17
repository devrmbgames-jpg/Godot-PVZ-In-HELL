@tool
extends GameDefinition
## Авторская мастерская одной личности; изменяемая кампания живёт в C_Crafting.
class_name DEF_CraftingProfile

## Обратимые рецепты и простые формы прототипа не объявляются финальным каноном.
@export var prototype: bool = true
## Постоянная личность изготовителя; принятые партии не зависят от его текущей жизни.
@export var npc_id: StringName = &"npc/3"
## Имя мастерской для native контейнера и подтверждения.
@export var display_name: String = "Мастерская Тихона"
## Валидированный каталог распознавания по точному составу/сложности/приоритету.
@export var recipes: Array[DEF_CraftingRecipe] = []
## Доступный полный рецепт для первой обучающей надписи, обязательно из recipes.
@export var hint_recipe: DEF_CraftingRecipe = null
## Реальный физический результат каждой последующей полностью неудачной партии.
@export var trash: DEF_InventoryItem = null
## Авторское число отдельных экземпляров мусора, не количество подаренных ингредиентов.
@export_range(1, 99) var trash_quantity: int = 1
## Ограниченные позиции размещения внутри native ящика; глобальная очередь лута не меняется.
@export var placement: DEF_ItemPlacement = preload(
	"res://content/shared/definitions/def_item_placement_default.tres"
)
