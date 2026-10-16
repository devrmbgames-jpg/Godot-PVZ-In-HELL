extends Component
## Transient hidden episode and camera sample; personal history belongs to NpcRecord.
class_name C_NpcStalking

## Construction/restore-selected immutable capability; null means ordinary behavior.
@export var rule: DEF_NpcStalking = null
## S_NpcStalkingWitness owns whether the actual player camera currently observes this body.
var observed: bool = false
## Witness initializes sensing without manufacturing a new opportunity after reset/load.
var context_initialized: bool = false
## Previous suitable hidden situation; a false-to-true edge may create one social opportunity.
var context_available: bool = false
## Previous actual terminal-reading state; beginning to read can provide a new distraction.
var terminal_reading: bool = false
## Witness creates/expires this bounded desire; begin() consumes it exactly once.
var opportunity_available: bool = false
## Absolute GameClock expiry of that unconsumed desire; zero when none is pending.
var opportunity_expires_tick: int = 0
## Committed personal opportunity represented by this transient episode; zero means inactive.
var episode_sequence: int = 0
## Once-selected GameClock timestamps; no BT/service delta accumulator owns time.
var ready_tick: int = 0
## Absolute end of this bounded attempt, including its initial delay.
var deadline_tick: int = 0
## Once-selected extra successful cooldown, in GameClock ticks.
var success_extra_ticks: int = 0
## First preferred rear sector, selected once per opportunity.
var candidate_offset: int = 0
## Captured route destination; INF means the first route has not been selected.
var destination: Vector3 = Vector3.INF
## Player position at the most recent bounded route selection.
var sampled_position: Vector3 = Vector3.ZERO
## Original free-episode position bounds roaming independently of the moving player.
var origin: Vector3 = Vector3.ZERO
## Absolute earliest next route selection and remaining count; approach leaf owns consumption.
var next_replan_tick: int = 0
## Additional selections left after the first destination.
var replans_left: int = 0
## Native approach leaf token; sensing can suppress only that leaf's current movement.
var approach_task_id: int = 0
## Last sampled camera-owner incarnation for diagnostics; R_NpcStalkingTarget owns the live binding.
var sampled_player_instance_id: int = 0


#region Transient lifecycle
## Clears sensing at reset/participation boundaries without erasing durable personal detection.
func reset_transient_state() -> void:
	observed = false
	context_initialized = false
	context_available = false
	terminal_reading = false
	opportunity_available = false
	opportunity_expires_tick = 0
	sampled_player_instance_id = 0
	reset_episode()


## Clears only the attempt cache; its live target is released by NpcStalkingService.cancel.
func reset_episode() -> void:
	episode_sequence = 0
	ready_tick = 0
	deadline_tick = 0
	success_extra_ticks = 0
	candidate_offset = 0
	destination = Vector3.INF
	sampled_position = Vector3.ZERO
	origin = Vector3.ZERO
	next_replan_tick = 0
	replans_left = 0
	approach_task_id = 0
#endregion
