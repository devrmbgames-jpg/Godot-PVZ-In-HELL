extends GameDefinition
## Авторское предложение будущего улучшения; исполняемого эффекта пока нет.
class_name DEF_Upgrade

## Отображаемое название предложения улучшения.
@export var display_name: String = "Улучшение"
## Цена предложения в целых денежных единицах.
@export_range(0, 1000000000) var market_price: int = 100
