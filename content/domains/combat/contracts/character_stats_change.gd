extends RefCounted
## Explicit permanent attribute transaction; voluntary forfeiture uses common Health calculation.
class_name CharacterStatsChange

## Live target established by the synchronous caller.
var target: Entity = null
## Stable initiator identity for common Health results after the dealer disappears.
var origin_id: String = ""
## Permanent positive Strength change.
var strength_delta: float = 0.0
## Permanent negative maximum-Health change.
var maximum_health_delta: float = 0.0
## True forfeits all remaining HP through the common depletion/death boundary.
var forfeit_life: bool = false
## Stable operation identity for outcome attribution; caller owns idempotency.
var confirmation_key: StringName = &""
