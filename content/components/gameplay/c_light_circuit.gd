extends Component
## Авторское состояние световой цепи; выключатели меняют enabled, представление читает его.
class_name C_LightCircuit

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["enabled"]

## Постоянный ID цепи для выключателей, зон света и событий.
@export var circuit_id: StringName = &"warehouse"
## Авторские группы Light3D, визуально подключённые к этой цепи.
@export var light_groups: Array[StringName] = [&"warehouse_lights"]
## Авторитетное состояние выключателя; мерцание не меняет его.
@export var enabled: bool = true
