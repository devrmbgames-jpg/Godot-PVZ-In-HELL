extends Resource
## Зафиксированная дневная партия; незавершённая коробка сохраняет свою позицию.
class_name ReceivingBatch

## Exact durable recipe fields; omissions must not silently discard a committed order.
const SAVE_FIELDS: Array[String] = [
	"source",
	"day_index",
	"next_package",
	"package_keys",
	"package_scenes",
	"order_item_paths",
	"order_quantities",
	"order_packing_paths",
]

enum Source {
	BASE_SUPPLY,
	PENDING_ORDER,
}

## Вид источника партии; обычная утренняя поставка использует BASE_SUPPLY.
@export var source: Source = Source.BASE_SUPPLY
## Игровой день, входящий в постоянные ID создаваемых коробок.
@export var day_index: int = 0
## Индекс следующей позиции в зафиксированном списке package_keys, начиная с нуля.
@export var next_package: int = 0
## Ключи выбранных коробок; сохраняются, чтобы загрузка не пересобирала партию.
@export var package_keys: PackedStringArray = []
## Выбранные один раз физические варианты; занятность места и перезапуск не меняют коробку.
@export var package_scenes: PackedStringArray = []
## Parallel committed item-definition paths; an empty entry explicitly retains legacy contents.
@export var order_item_paths: PackedStringArray = []
## Parallel frozen unit counts; zero explicitly retains non-catalog authored contents.
@export var order_quantities: PackedInt32Array = []
## Parallel immutable packing paths; empty only for non-catalog authored contents.
@export var order_packing_paths: PackedStringArray = []
