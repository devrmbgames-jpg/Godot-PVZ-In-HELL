extends Component
## Physical marker configuration and its temporary drawing session.
class_name C_Marker

## Maximum camera-to-surface distance in meters.
@export var drawing_range: float = 3.0
## Ink ribbon width in package-local meters.
@export var ink_width: float = 0.012
## Visible ink color; not interpreted as text or warehouse metadata.
@export var ink_color: Color = Color(0.025, 0.035, 0.09)
## Minimum distance between accepted samples in local meters.
@export var sample_spacing: float = 0.004
## Maximum samples stored per package, bounding runtime memory and mesh size.
@export var max_package_points: int = 4096
## Session owner and independent capture token; cleared by S_Marker.
var actor: Entity = null
var capture_token: int = 0
## Virtual viewport pointer while camera look is captured.
var pointer: Vector2 = Vector2.ZERO
## Current stroke continuity; misses, button release and face changes split it.
var parcel: Entity = null
var stroke: PackageMarkStroke = null
