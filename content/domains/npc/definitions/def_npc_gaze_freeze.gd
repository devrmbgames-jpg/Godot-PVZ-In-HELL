@tool
extends DEF_NpcTrait
## Authored visibility constraint; sensing, native freeze and BT priority have separate owners.
class_name DEF_NpcGazeFreeze

const MAXIMUM_SAMPLES: int = 16

## Actor-local body points; any unoccluded point in the player's camera frustum freezes it.
@export var sample_offsets: Array[Vector3] = [
	Vector3(0.0, 0.2, 0.0),
	Vector3(0.0, 0.9, 0.0),
	Vector3(0.0, 1.6, 0.0),
	Vector3(-0.25, 1.2, 0.0),
	Vector3(0.25, 1.2, 0.0),
]
## Solid layers that occlude observation; Areas and the observing/observed bodies are excluded.
@export_flags_3d_physics var visibility_mask: int = 31


#region Authored validation
func _init() -> void:
	kind = Kind.CAPABILITY


func valid_configuration() -> bool:
	if (
		kind != Kind.CAPABILITY or visibility_mask <= 0
		or sample_offsets.is_empty() or sample_offsets.size() > MAXIMUM_SAMPLES
	):
		return false
	for offset: Vector3 in sample_offsets:
		if not offset.is_finite() or offset.length() > 10.0:
			return false
	return true
#endregion
