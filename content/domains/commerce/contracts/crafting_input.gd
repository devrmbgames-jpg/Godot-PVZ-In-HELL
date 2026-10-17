extends Resource
## Зафиксированный физический стек и его происхождение/состояние на момент передачи.
class_name CraftingInput

## Закрытый durable контракт; ни одно поле не выводится из будущего состояния оболочки.
const SAVE_FIELDS: Array[String] = [
	"entity_id",
	"definition",
	"quantity",
	"source_package_id",
	"source_history_id",
	"intact",
	"full_blood",
	"removed",
]

## Точный стабильный ID принятого физического экземпляра.
@export var entity_id: String = ""
## Авторский тип материала или подарка.
@export var definition: DEF_InventoryItem = null
## Фактическое принятое количество; в плане подарков — только неиспользованный остаток.
@export var quantity: int = 0
## Источник извлечённого содержимого, пусто для обычного имущества.
@export var source_package_id: String = ""
## Исторически известный archive ID, не дополняется поздней регистрацией коробки.
@export var source_history_id: String = ""
## Материал не разрушен по фактическому health/lifecycle на момент передачи.
@export var intact: bool = true
## Полная колба крови с неизрасходованным одноразовым emitter в момент передачи.
@export var full_blood: bool = false
## Переданный стек целиком выбыл, включая его подаренную часть.
@export var removed: bool = false
