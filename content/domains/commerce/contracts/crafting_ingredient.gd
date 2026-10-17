@tool
extends Resource
## Одно авторское требование рецепта; один тип встречается в рецепте ровно один раз.
class_name CraftingIngredient

## Закрытый контракт исторической копии требования в принятом шаге.
const SAVE_FIELDS: Array[String] = [
	"definition",
	"quantity",
	"require_intact",
	"require_full_blood",
]

## Точный тип материала; названия и категории не заменяют определение.
@export var definition: DEF_InventoryItem = null
## Положительное число единиц, расходуемых за одно изделие.
@export_range(1, 99) var quantity: int = 1
## Требует неразрушенный материал по фактическому состоянию тела.
@export var require_intact: bool = true
## Только полноценная колба крови, чей одноразовый emitter ещё не израсходован.
@export var require_full_blood: bool = false
