@tool
extends DEF_NpcTrait
## Immutable stealth approach and recognition tuning; decisions still belong to native BT branches.
class_name DEF_NpcStalking

## Maximum perceived-player approach range in metres.
@export_range(1.0, 30.0) var approach_range: float = 8.0
## Extra approach range while that player is reading a native terminal, in metres.
@export_range(0.0, 20.0) var terminal_range_bonus: float = 4.0
## Desired distance behind the actual player camera direction, in metres.
@export_range(0.5, 5.0) var behind_distance: float = 1.8
## Native arrival tolerance, in metres.
@export_range(0.1, 1.0) var arrival_tolerance: float = 0.35
## Probability of consuming a suitable social opportunity as a hidden approach, rolled once.
@export_range(0.0, 1.0) var opportunity_probability: float = 0.6
## Maximum active duration of one free approach after its selected delay, in seconds.
@export_range(1.0, 15.0) var episode_seconds: float = 8.0
## Upper bound of the once-selected initial delay, in active seconds.
@export_range(0.0, 5.0) var delay_seconds: float = 2.0
## Minimum interval after a skipped/interrupted opportunity, in active seconds.
@export_range(1.0, 30.0) var retry_seconds: float = 10.0
## Added once-selected successful cooldown, above the owner-defined minimum30 seconds.
@export_range(0.0, 30.0) var success_extra_seconds: float = 30.0
## Transient scale consumed by S_NpcIntent; personal max_speed remains unchanged.
@export_range(1.0, 2.0) var approach_speed_multiplier: float = 1.5
## Minimum interval between meaningful target replans, in active seconds.
@export_range(0.2, 3.0) var replan_seconds: float = 1.0
## Player displacement required to reconsider the captured destination, in metres.
@export_range(0.2, 3.0) var replan_distance: float = 0.8
## Maximum additional route selections after the initial destination.
@export_range(0, 3) var max_replans: int = 2
## Solid collision mask shared by current observation and candidate-route visibility.
@export_flags_3d_physics var visibility_mask: int = 31
## Authored local body sample positions; empty/non-finite samples are invalid.
@export var sample_offsets: Array[Vector3] = [
	Vector3(0.0, 1.5, 0.0),
	Vector3(0.0, 0.9, 0.0),
	Vector3(0.0, 0.25, 0.0),
]


#region Authored capability
func _init() -> void:
	kind = Kind.CAPABILITY


func valid_configuration() -> bool:
	if (
		kind != Kind.CAPABILITY or not is_finite(approach_range) or approach_range <= 0.0
		or not is_finite(terminal_range_bonus) or terminal_range_bonus < 0.0
		or not is_finite(behind_distance) or behind_distance <= 0.0
		or not is_finite(arrival_tolerance) or arrival_tolerance <= 0.0
		or arrival_tolerance >= behind_distance or visibility_mask <= 0 or sample_offsets.is_empty()
	):
		return false
	for value: float in [
		opportunity_probability, episode_seconds, delay_seconds, retry_seconds,
		success_extra_seconds, approach_speed_multiplier, replan_seconds, replan_distance,
	]:
		if not is_finite(value):
			return false
	if (
		opportunity_probability < 0.0 or opportunity_probability > 1.0
		or episode_seconds < 1.0 or episode_seconds > 15.0
		or delay_seconds < 0.0 or delay_seconds > 5.0
		or retry_seconds < 1.0 or retry_seconds > 30.0
		or success_extra_seconds < 0.0 or success_extra_seconds > 30.0
		or approach_speed_multiplier < 1.0 or approach_speed_multiplier > 2.0
		or replan_seconds < 0.2 or replan_seconds > 3.0
		or replan_distance < 0.2 or replan_distance > 3.0 or max_replans < 0 or max_replans > 3
	):
		return false
	for offset: Vector3 in sample_offsets:
		if not offset.is_finite():
			return false
	return true
#endregion
