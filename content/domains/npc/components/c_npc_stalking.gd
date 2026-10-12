extends Component
## Derived stalking inputs and camera exposure; durable detection belongs to personal memory.
class_name C_NpcStalking

## Construction/restore-selected immutable capability; null means ordinary behavior.
@export var rule: DEF_NpcStalking = null
## S_NpcStalkingWitness owns whether the actual player camera currently observes this body.
var observed: bool = false
## S_NpcStalkingWitness owns uninterrupted exposure duration, in seconds.
var exposure_seconds: float = 0.0
## Native approach leaf token; sensing can suppress only that leaf's current movement.
var approach_task_id: int = 0
## Transient sampled player incarnation; replacement cannot inherit camera exposure.
var sampled_player_instance_id: int = 0


#region Transient lifecycle
## Clears sensing at reset/participation boundaries without erasing durable personal detection.
func reset_transient_state() -> void:
	observed = false
	exposure_seconds = 0.0
	approach_task_id = 0
	sampled_player_instance_id = 0
#endregion
