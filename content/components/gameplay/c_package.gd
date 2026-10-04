extends Component
## Постоянная идентичность поставки и признак инициализации, независимые от состояния коробки.
class_name C_Package

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
