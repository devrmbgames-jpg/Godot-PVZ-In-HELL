extends Component
## Authored transport motion limits plus cart-local derived/runtime state.
class_name C_CartTransport

@export var forward_speed: float = 2.0
@export var reverse_speed: float = 1.5
@export var acceleration: float = 5.0
@export var turn_speed: float = 1.2
@export var step_height: float = 0.2
@export var floor_snap: float = 0.3
@export var gravity: float = 18.0
@export var handle_distance: float = 1.6
@export var follow_speed: float = 5.0
@export var follow_tolerance: float = 0.65
@export var focus_distance: float = 4.0
@export var cargo_settle_seconds: float = 0.15
@export var cargo_settle_speed: float = 0.5
@export var cargo_follow_speed: float = 8.0
@export var cargo_break_distance: float = 0.35

## Derived/rebuildable reverse cache. R_CartCargo remains the sole cargo authority.
var cargo: Array[Entity] = []
## Cart-local transient candidate timers; not ownership.
var settling: Dictionary[int, float] = { }
## Intrinsic runtime motion state.
var drive_speed: float = 0.0
var actual_velocity: Vector3 = Vector3.ZERO
