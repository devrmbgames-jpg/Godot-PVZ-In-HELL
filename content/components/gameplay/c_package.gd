extends Component
class_name C_Package

## Persistent identity, unrelated to Node paths or engine instance IDs.
@export var package_id: String = ""
## Shared immutable design data; runtime systems must not mutate this resource.
@export var definition: DEF_Package = null
@export var delivery_day: int = 0
@export var supply_key: StringName = &""
