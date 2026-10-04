extends Component
## Логическое состояние замка и запроса движения; физическое исполнение принадлежит контроллеру тела.
class_name C_Openable

## Замок запрещает запрос обычного открытия и закрытия.
@export var locked: bool = false
## Необязательное требование предмета для разблокировки.
@export var access: DEF_AccessRequirement = null
## Общие авторские положения, время движения и параметры мотора.
@export var motion: DEF_OpenableMotion = null
## Запрошено открытие; намерение не подтверждает фактическое перемещение тела.
@export var requested_open: bool = false
## Фактическая доля открытия 0–1; записывается по реальному положению через report_fraction.
@export_range(0.0, 1.0) var actual_fraction: float = 0.0
