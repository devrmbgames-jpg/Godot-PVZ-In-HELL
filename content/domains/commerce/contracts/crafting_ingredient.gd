@tool
extends Resource
## Одно авторское требование рецепта; один тип встречается в рецепте ровно один раз.
class_name CraftingIngredient

## Точный тип материала; названия и категории не заменяют определение.
@export var definition: DEF_InventoryItem = null
## Положительное число единиц, расходуемых за одно изделие.
@export_range(1, 99) var quantity: int = 1
## Требует неразрушенный материал по фактическому состоянию тела.
@export var require_intact: bool = true
## Только полноценная колба крови, чей одноразовый emitter ещё не израсходован.
@export var require_full_blood: bool = false
