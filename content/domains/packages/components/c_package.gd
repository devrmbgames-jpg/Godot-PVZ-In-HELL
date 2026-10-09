extends C_ActorIdentityReference
## Постоянная идентичность поставки и признак инициализации, независимые от состояния коробки.
class_name C_Package

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = [
	"package_id",
	"history_id",
	"definition",
	"delivery_day",
	"supply_key",
]

## Постоянный ID, независимый от путей Node и instance ID движка.
@export var package_id: String = ""
## Скрытый читаемый ID истории; для выдачи клиенту используется отдельный регистрационный номер.
@export var history_id: String = ""
## Общие авторские данные; игровые системы не изменяют этот ресурс.
@export var definition: DEF_Package = null
## День фактической поставки физической коробки.
@export var delivery_day: int = 0
## Ключ авторского ассортимента, из которого создана посылка.
@export var supply_key: StringName = &""

## Защита от повторной инициализации; загрузка ставит флаг перед восстановлением Health.
var condition_initialized: bool = false

#region Existing identity projection
## Читает actor key непосредственно из авторитетного поля этого Component.
func actor_key() -> String:
	return "package/" + package_id


## Сохраняет приоритет существующего ключа при восстановлении actor links.
func actor_key_priority() -> Specificity:
	return Specificity.PRIMARY


## Читает диагностический ID непосредственно из авторитетного поля этого Component.
func trace_key() -> String:
	return package_id


## Сохраняет приоритет существующего domain ID перед runtime identity.
func trace_key_priority() -> Specificity:
	return Specificity.PRIMARY
#endregion
