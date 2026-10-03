extends GameDefinition
class_name DEF_InventoryItem

enum Kind { FOOD, MED_ITEM, BUBBLE_WRAP, FURNITURE }

## Whole-money market price, independent of Package accounting value.
@export_range(0, 1000000000) var market_price: int = 25
@export var display_name: String = "Предмет"
@export var icon: Texture2D = null
## String path avoids a recursive Definition -> scene -> Definition resource dependency.
@export_file("*.tscn") var world_pickup_scene: String = ""
@export var kind: Kind = Kind.FOOD
@export_range(1, 99) var maximum_stack: int = 10
@export var food_effect: DEF_FoodEffect = null
@export var healing: float = 35.0
@export var protection_tier: ImpactResult.Severity = ImpactResult.Severity.Medium
