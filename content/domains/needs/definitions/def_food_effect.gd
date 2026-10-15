extends GameDefinition
## Immutable food Definition; HungerService уменьшает голод, inventory решает расход единицы.
class_name DEF_FoodEffect

## Положительное уменьшение голода при принятом использовании еды.
@export var hunger_relief: float = 35.0
