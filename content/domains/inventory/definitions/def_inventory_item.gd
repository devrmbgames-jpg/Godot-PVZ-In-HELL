@tool
extends GameDefinition
## Авторское описание предмета инвентаря, цены и эффекта использования.
class_name DEF_InventoryItem

enum Kind {
	FOOD,
	MED_ITEM,
	BUBBLE_WRAP,
	FURNITURE,
	VALUABLE,
	PHYSICAL,
}

## Shopping categories are independent of inventory use effects and physical capabilities.
enum Category {
	WEAPON = 1,
	CLOTHING = 2,
	ARTIFACT = 4,
	REAGENT = 8,
	TOY = 16,
	VALUABLE = 32,
}

## Authored shopping-category mask; zero means no category is assigned.
@export_flags("WEAPON", "CLOTHING", "ARTIFACT", "REAGENT", "TOY", "VALUABLE")
var categories: int = 0

## Цена единицы в целых денежных единицах, отдельно от учётной стоимости посылок.
@export_range(0, 1000000000) var market_price: int = 25
## Отображаемое название предмета.
@export var display_name: String = "Предмет"
## Иконка стека для интерфейса.
@export var icon: Texture2D = null
## Строковый путь сцены избегает рекурсивной зависимости Definition → scene → Definition.
@export_file("*.tscn") var world_pickup_scene: String = ""
## Вид эффекта и способ хранения; мебель создаётся физически.
@export var kind: Kind = Kind.FOOD
## Авторский признак крупной мебели, для которой торговец предлагает доставку.
@export var bulky_furniture: bool = false
## Максимальное число единиц одного стека.
@export_range(1, 99) var maximum_stack: int = 10
## Эффект питания для FOOD.
@export var food_effect: DEF_FoodEffect = null
## Восстанавливаемое здоровье для MED_ITEM; применяется через контур урона.
@export var healing: float = 35.0
## Уровень защиты посылки после использования BUBBLE_WRAP.
@export var protection_tier: ImpactResult.Severity = ImpactResult.Severity.MEDIUM


#region Storage policy
## Physical-only catalog entries materialize a native body and never enter a virtual stack.
func requires_world_body() -> bool:
	return kind in [Kind.FURNITURE, Kind.PHYSICAL]
#endregion
