extends Resource
## Зафиксированная обычная цена типа в прайсе дня; не live предмет или его количество.
class_name BuybackItemPrice

## Точный durable контракт; отсутствующие поля не заменяются значениями по умолчанию.
const SAVE_FIELDS: Array[String] = ["definition", "base_price", "ordinary_price", "premium_price"]

## Неизменяемое определение оцениваемого типа.
@export var definition: DEF_InventoryItem = null
## Базовая авторская оценка на момент фиксации цены, до последующей продажи/смены дня.
@export var base_price: int = 0
## Цена единицы, сохранённая при первом включении типа в прайс дня.
@export var ordinary_price: int = 0
## Цена 150% базы на момент фиксации прайса; последующая продажа не меняет её.
@export var premium_price: int = 0
