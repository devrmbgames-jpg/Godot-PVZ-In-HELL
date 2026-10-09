extends System
## Advances gameplay ticks; calendar transitions never synthesize elapsed night time.
class_name S_GameTime

#region Scheduled clock ownership
## Selects the session-owned clock aggregate without depending on gameplay consumers.
func query() -> QueryBuilder:
	return q.with_all([C_DayCycle]).iterate([C_DayCycle])


## Commits whole microsecond ticks and carries the fractional remainder into the next step.
func process(_entities: Array[Entity], components: Array, delta: float) -> void:
	var cycles: Array = components[0]
	for cycle: C_DayCycle in cycles:
		var clock: GameClock = cycle.clock
		clock.step_ticks = 0
		if clock.paused or cycle.phase == C_DayCycle.Phase.NIGHT:
			continue
		if not is_finite(delta) or delta < 0.0:
			continue

		assert(GameTimeRules.valid(clock), "Gameplay clock must contain valid durable state")
		var fractional_ticks: float = delta * float(GameTimeRules.TICKS_PER_SECOND)
		fractional_ticks += clock.tick_remainder
		assert(fractional_ticks <= GameTimeRules.MAX_STEP_TICKS, "Clock step exceeds exact range")
		var whole_ticks: int = floori(fractional_ticks)
		assert(clock.elapsed_ticks <= 9223372036854775807 - whole_ticks, "Clock overflow")

		clock.tick_remainder = fractional_ticks - float(whole_ticks)
		clock.elapsed_ticks += whole_ticks
		clock.step_ticks = whole_ticks
#endregion
