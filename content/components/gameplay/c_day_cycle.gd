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
## R11 owns this count when the real customer schedule is installed.
@export var remaining_customer_events: int = 0
## R21 may hold Night until results, orders and persistence finish successfully.
var night_ready: bool = true
var pending_transition: DayTransitionRequest = null
