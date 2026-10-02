extends DEF_ChallengeCondition
class_name DEF_LightChallengeCondition

@export var circuit_id: StringName = &"warehouse"
@export var required_enabled: bool = false
## An arrival-only dark-room customer waits at Entry until the switch is off.
@export var wait_outside_until_dark: bool = false
@export_range(0.05, 2.0) var flicker_interval_seconds: float = 0.15
