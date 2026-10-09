extends GameDefinition
## Авторский эффект еды; решение о расходовании единицы принадлежит инвентарю.
class_name DEF_FoodEffect

## Положительное уменьшение голода при принятом использовании еды.
@export var hunger_relief: float = 35.0
