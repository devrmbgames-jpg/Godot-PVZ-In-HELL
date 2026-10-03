extends Component
class_name C_DayCycle

enum Phase {
	MORNING,
	DAY,
	EVENING,
	NIGHT,
}

@export var phase: Phase = Phase.MORNING
@export var day_index: int = 1
## S_CustomerFlow owns this count for customer events currently eligible to arrive.
@export var remaining_customer_events: int = 0
@export_group("Shift completion")
## Legacy behavior; may be disabled independently of the additional gates.
@export var require_finished_customers: bool = true
@export var require_empty_customer_room: bool = false
## Relative to DaySession. Empty means every live customer counts conservatively.
@export_node_path("Area3D") var customer_room_path: NodePath = NodePath("")
@export_range(0.0, 86400.0, 1.0, "or_greater") var minimum_shift_seconds: float = 0.0
@export var require_all_planned_arrivals: bool = false
## Transient; snapshots restore Morning, where a new shift starts with zero elapsed time.
var shift_elapsed_seconds: float = 0.0
## R21 may hold Night until results, orders and persistence finish successfully.
var night_ready: bool = true
var pending_transition: DayTransitionRequest = null
