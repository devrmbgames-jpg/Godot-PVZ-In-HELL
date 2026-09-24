extends RefCounted
## Future night-reset boundary; persistence exempts an effect from reset, not from its own TTL.
class_name HazardResetRequest

const EVENT: StringName = &"hazard_reset_requested"

## Explicit full cleanup also removes persistent effects, e.g. when resetting a scenario.
var include_persistent: bool = false
