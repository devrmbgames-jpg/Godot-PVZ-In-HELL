extends Component
## Physical marker configuration and temporary drawing-session state.
class_name C_Marker

@export var drawing_range: float = 3.0
@export var ink_width: float = 0.012
@export var ink_color: Color = Color(0.025, 0.035, 0.09)
@export var sample_spacing: float = 0.004
@export var max_package_points: int = 4096
## The holder is always derived from R_HeldBy; this token belongs only to drawing focus.
var capture_token: int = 0
var pointer: Vector2 = Vector2.ZERO
## Current stroke continuity; this is transient cursor state, not package ownership.
var parcel: Entity = null
var stroke: PackageMarkStroke = null
