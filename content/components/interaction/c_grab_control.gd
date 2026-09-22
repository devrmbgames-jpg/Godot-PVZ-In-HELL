extends Component
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
@export var swap_hand_controls: bool = false
