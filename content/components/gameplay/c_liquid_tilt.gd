extends Component
## Continuous unsafe-tilt exposure; created only for Liquid package definitions.
class_name C_LiquidTilt

## Maximum allowed angle from world up and uninterrupted seconds beyond it.
@export_range(0.0, 180.0) var maximum_angle_degrees: float = 60.0
@export_range(0.0, 30.0) var duration_seconds: float = 2.0
## Optional one-shot non-impact HP damage when leaking starts.
@export_range(0.0, 10000.0) var damage_amount: float = 10.0
## Runtime timer and committed exposure guard.
var unsafe_seconds: float = 0.0
var triggered: bool = false
