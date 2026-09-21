extends RefCounted
class_name DayTransitionRequest

enum Kind {
	START_SHIFT,
	FINISH_SHIFT,
	SLEEP,
}

var kind: Kind = Kind.START_SHIFT
var expected_day: int = 0
var expected_phase: C_DayCycle.Phase = C_DayCycle.Phase.MORNING
