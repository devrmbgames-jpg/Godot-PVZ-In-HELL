extends Resource
## Обратимый скрытый ID истории и отладки посылки; не является номером выдачи.
## Формат: <день>-<порядковый номер дня>-<опасность><размер><масса в 0,1 кг, base36>.
class_name PackageHistoryId

enum SizeClass {
	SMALL,
	MEDIUM,
	LARGE,
	OVERSIZED,
}

const BASE36: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const HAZARD_CODES: Array[String] = ["N", "F", "L", "T", "X", "O"]
const SIZE_CODES: Array[String] = ["S", "M", "L", "X"]
const MASS_SCALE: int = 10
const MASS_DIGITS: int = 3
const MAX_MASS_TENTHS: int = 46655
const HASH_LENGTH: int = 5

## Номер дня поставки, начиная с 1.
@export var day_index: int = 0
## Порядковый номер истории внутри этого дня, начиная с 1.
@export var number: int = 0
## Диагностический класс из DEF_Package.HazardClass.
@export var hazard_class: int = DEF_Package.HazardClass.NORMAL
## Класс размера, используемый в коде истории.
@export var size_class: int = SizeClass.MEDIUM
## Округлённая масса в десятых долях килограмма, 0–46655.
@export var mass_tenths_kg: int = 0


#region Кодирование и чтение ID
## Кодирует скрытый ID; возвращает пустую строку при недопустимых данных.
func serialize() -> String:
	if day_index < 1 or number < 1:
		return ""
	if hazard_class < DEF_Package.HazardClass.NORMAL or hazard_class > DEF_Package.HazardClass.OTHER:
		return ""
	if size_class < SizeClass.SMALL or size_class > SizeClass.OVERSIZED:
		return ""
	if mass_tenths_kg < 0 or mass_tenths_kg > MAX_MASS_TENTHS:
		return ""

	var mass_code: String = _encode_base36(mass_tenths_kg, MASS_DIGITS)
	if mass_code.is_empty():
		return ""
	return "%d-%02d-%s%s%s" % [
		day_index,
		number,
		HAZARD_CODES[hazard_class],
		SIZE_CODES[size_class],
		mass_code,
	]


## Возвращает пятисимвольную диагностическую часть ID, иначе пустую строку.
func hash_code() -> String:
	var serialized: String = serialize()
	if serialized.is_empty():
		return ""
	return serialized.get_slice("-", 2)


## Переводит сохранённую массу из десятых долей в килограммы.
func decoded_mass_kg() -> float:
	return float(mass_tenths_kg) / float(MASS_SCALE)


## Декодирует и проверяет ID; при неверном формате или значении возвращает null.
static func parse(value: String) -> PackageHistoryId:
	var parts: PackedStringArray = value.split("-", false)
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return null

	var encoded: String = parts[2].to_upper()
	if encoded.length() != HASH_LENGTH:
		return null

	var hazard_index: int = HAZARD_CODES.find(encoded.substr(0, 1))
	var size_index: int = SIZE_CODES.find(encoded.substr(1, 1))
	var mass_value: int = _decode_base36(encoded.substr(2, MASS_DIGITS))
	if hazard_index < 0 or size_index < 0 or mass_value < 0:
		return null

	var parsed: PackageHistoryId = PackageHistoryId.new()
	parsed.day_index = parts[0].to_int()
	parsed.number = parts[1].to_int()
	parsed.hazard_class = hazard_index
	parsed.size_class = size_index
	parsed.mass_tenths_kg = mass_value
	return parsed if not parsed.serialize().is_empty() else null


#endregion

#region Кодирование массы base36
static func _encode_base36(value: int, width: int) -> String:
	if value < 0 or width < 1:
		return ""

	var current: int = value
	var result: String = ""
	for _index: int in width:
		result = BASE36.substr(current % BASE36.length(), 1) + result
		@warning_ignore("integer_division")
		current = current / BASE36.length()
	if current > 0:
		return ""
	return result


static func _decode_base36(value: String) -> int:
	var result: int = 0
	for index: int in value.length():
		var digit: int = BASE36.find(value.substr(index, 1).to_upper())
		if digit < 0:
			return -1

		result = result * BASE36.length() + digit
	return result

#endregion
