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
## Continuous unobstructed camera exposure required to commit detection, in seconds.
@export_range(0.1, 5.0) var notice_seconds: float = 0.5
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
		or arrival_tolerance >= behind_distance or not is_finite(notice_seconds)
		or notice_seconds <= 0.0 or visibility_mask <= 0 or sample_offsets.is_empty()
	):
		return false
	for offset: Vector3 in sample_offsets:
		if not offset.is_finite():
			return false
	return true
#endregion
