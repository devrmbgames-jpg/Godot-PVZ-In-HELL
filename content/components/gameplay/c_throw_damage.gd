extends Component
## Optional source bonus for a deliberate throw, never for ordinary falls or pushes.
class_name C_ThrowDamage

## Extra HP damage on the first qualifying physical hit within the configured window.
@export_range(0.0, 10000.0) var throw_damage: float = 10.0
@export_range(0.0, 30.0) var window_seconds: float = 3.0
## Runtime context owned by S_Impact; source identity remains the thrown Entity.
var instigator: Entity = null
var remaining_seconds: float = 0.0
var armed_tick: int = -1
