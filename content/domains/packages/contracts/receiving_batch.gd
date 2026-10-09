extends Resource
## Зафиксированная дневная партия; незавершённая коробка сохраняет свою позицию.
class_name ReceivingBatch

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
