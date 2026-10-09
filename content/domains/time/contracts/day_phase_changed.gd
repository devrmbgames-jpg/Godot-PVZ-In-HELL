extends RefCounted
## Committed day/phase snapshot; bootstrap may publish the already-authored current phase.
class_name DayPhaseChanged

## Explicit phase fact channel, separate from transition requests.
const EVENT: StringName = &"day_phase_changed"
## Committed gameplay day.
var day_index: int = 0
## Committed phase; a queued consumer must reject a superseded snapshot.
var phase: C_DayCycle.Phase = C_DayCycle.Phase.MORNING

#region Fact construction
## Copies committed state without retaining a mutable cycle reference.
static func from_cycle(cycle: C_DayCycle) -> DayPhaseChanged:
	var fact: DayPhaseChanged = DayPhaseChanged.new()
	fact.day_index = cycle.day_index
	fact.phase = cycle.phase
	return fact
#endregion
