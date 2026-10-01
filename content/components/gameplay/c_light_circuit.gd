extends Component
## Authored circuit state for switches and future challenge conditions.
class_name C_LightCircuit

@export var circuit_id: StringName = &"warehouse"
@export var light_groups: Array[StringName] = [&"warehouse_lights"]
@export var enabled: bool = true
