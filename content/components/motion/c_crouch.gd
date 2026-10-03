extends Component
class_name C_Crouch


@export var active: bool = false

@export var camera_height_standing: float = 1.7
@export var camera_height_crouching: float = 1.0

@export var transition_speed: float = 8.0

## Доля опускания HeadRoot для поясных креплений; ниже камеры, выше пола.
@export_range(0.0, 1.0, 0.05) var belt_lowering_ratio: float = 0.75
