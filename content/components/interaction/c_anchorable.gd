extends Component
## Authored anchoring policy plus runtime rest accumulation for a physical Entity.
class_name C_Anchorable

@export_range(0.0, 10.0, 0.01, "or_greater") var minimum_rest_seconds: float = 0.5
@export_range(0.0, 10.0, 0.01, "or_greater") var maximum_linear_speed: float = 0.05
@export_range(0.0, 10.0, 0.01, "or_greater") var maximum_angular_speed: float = 0.1
@export_range(0.001, 0.5, 0.001, "or_greater") var support_tolerance: float = 0.05
## Local direction in which this object bears on its support. Default is local down.
@export var support_direction_local: Vector3 = Vector3.DOWN

## Runtime-only accumulated stable time. S_AnchorStability is the sole writer.
var stable_seconds: float = 0.0
