extends Component
## Связь тела с постоянной личностью; не управляет целями боя и посылками.
class_name C_NpcIdentity

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["npc_id"]

## Постоянный ID личности района.
@export var npc_id: StringName = &""
