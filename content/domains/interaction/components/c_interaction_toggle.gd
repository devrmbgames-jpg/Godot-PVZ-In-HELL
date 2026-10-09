extends Component
## Сохраняемый результат авторского переключения вентиля.
class_name C_InteractionToggle

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["active"]

## Текущее положение авторского переключателя.
@export var active: bool = false
