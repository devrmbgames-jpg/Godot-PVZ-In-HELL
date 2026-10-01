extends GameDefinition
class_name DEF_InventoryItem

enum Kind { FOOD, MED_ITEM, BUBBLE_WRAP }

@export var display_name: String = "Предмет"
@export var kind: Kind = Kind.FOOD
@export_range(1, 99) var maximum_stack: int = 10
@export var food_effect: DEF_FoodEffect = null
@export var healing: float = 35.0
@export var protection_tier: ImpactResult.Severity = ImpactResult.Severity.Medium
