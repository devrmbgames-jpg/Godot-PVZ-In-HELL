extends RefCounted
## Reads the session clock and keyed RNG previews without changing time or sequences.
class_name GameTimeQueries

#region Required session clock
## Returns the unique clock aggregate established by the session's C_DayCycle contract.
static func current() -> GameClock:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	assert(cycle != null, "Gameplay time requires the session calendar owner")
	return cycle.clock


## Samples an explicit decision key using the saved world seed; callers own committed sequences.
static func decision(actor_id: String, day: int, kind: String,
		sequence: int = 0) -> RandomNumberGenerator:
	return DecisionRandomRules.generator(current().world_seed, actor_id, day, kind, sequence)


## Reads current/frozen shift duration from timestamps without accumulating another clock.
static func shift_seconds(cycle: C_DayCycle) -> float:
	if cycle.phase == C_DayCycle.Phase.MORNING or cycle.shift_start_tick < 0:
		return 0.0
	var end_tick: int = cycle.clock.elapsed_ticks
	if cycle.shift_end_tick >= 0:
		end_tick = cycle.shift_end_tick
	return GameTimeRules.seconds(maxi(0, end_tick - cycle.shift_start_tick))
#endregion
