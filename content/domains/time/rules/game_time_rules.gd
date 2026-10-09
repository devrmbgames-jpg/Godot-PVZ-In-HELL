extends RefCounted
## Pure conversions and validity checks for the gameplay clock, independent of wall time.
class_name GameTimeRules

## Fixed schema-9 quantum: one elapsed simulation tick is one microsecond.
const TICKS_PER_SECOND: int = 1_000_000
## Largest integer exactly representable by the floating-point step conversion.
const MAX_STEP_TICKS: int = 9_007_199_254_740_991

#region Units and validity
## Converts an integer elapsed interval for existing seconds-based native adapters.
static func seconds(ticks: int) -> float:
	return float(ticks) / float(TICKS_PER_SECOND)


## Rounds an authored nonnegative duration upward so a deadline never expires early.
static func duration_ticks(duration_seconds: float) -> int:
	assert(is_finite(duration_seconds) and duration_seconds >= 0.0)
	return ceili(duration_seconds * float(TICKS_PER_SECOND))


## Validates persistent clock state before applying a snapshot to the live session.
static func valid(clock: GameClock) -> bool:
	return clock != null and clock.elapsed_ticks >= 0 \
		and is_finite(clock.tick_remainder) \
		and clock.tick_remainder >= 0.0 and clock.tick_remainder < 1.0
#endregion
