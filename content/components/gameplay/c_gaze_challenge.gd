extends Component
## Derived observation/presentation data. Binding and timers remain in the shared challenge.
class_name C_GazeChallenge

var sample_valid: bool = false
var distance: float = 0.0
var angle_degrees: float = 0.0
var within_range: bool = false
var within_angle: bool = false
var line_of_sight: bool = false
var attention: bool = false
var warning_active: bool = false
