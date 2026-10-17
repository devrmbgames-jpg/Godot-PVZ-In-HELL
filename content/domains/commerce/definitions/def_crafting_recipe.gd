@tool
extends GameDefinition
## Неизменяемый распознаваемый набор и физический результат, без денежной доплаты.
class_name DEF_CraftingRecipe

## Читаемое авторское название; UI не раскрывает весь каталог автоматически.
@export var display_name: String = "Изделие"
## Полный состав одного применения; дублирующиеся типы запрещены проверкой каталога.
@export var ingredients: Array[CraftingIngredient] = []
## Сложность важнее числа изделий; более высокая выбирается первой.
@export_range(0, 1000) var complexity: int = 0
## Явный порядок при равной сложности, больше означает раньше.
@export var priority: int = 0
## Авторское определение реально переносимого физического изделия.
@export var output: DEF_InventoryItem = null
## Каждый экземпляр получит собственный стабильный output ID.
@export_range(1, 99) var output_quantity: int = 1
