extends Component
## Actor hold configuration, derived slot caches and shared interaction control state.
class_name C_GrabControl

## Maximum reach for picking up an object (metres).
@export_range(0.1, 10.0, 0.1, "or_greater") var pickup_distance: float = 3.0
## Distance in front of Holder for ordinary carried objects (metres).
@export_range(0.1, 5.0, 0.05, "or_greater") var hold_distance: float = 1.25
var rotation_active: bool = false
## Derived reverse index maintained by O_GrabLifecycle and checked against the relation.
## Never assign this to acquire ownership.
var held_carry: Entity = null
var held_right: Entity = null
var held_left: Entity = null
## Swaps primary/secondary controls without moving objects between physical hands.
@export var swap_hand_controls: bool = false
## Holding G beyond this time reserves the future context wheel and suppresses drop.
@export_range(0.1, 2.0, 0.05) var drop_long_press_seconds: float = 0.45
## Token registry is the single control-focus authority; each acquire has its own key.
var captures: Dictionary[int, InteractionControlCapture] = { }
var context_wheel_requested: bool = false
