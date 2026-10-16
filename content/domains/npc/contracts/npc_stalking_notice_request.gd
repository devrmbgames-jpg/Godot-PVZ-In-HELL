extends RefCounted
## Captured sensing boundary; queued recognition cannot retain or revive live actors.
class_name NpcStalkingNoticeRequest

const EVENT: StringName = &"npc_stalking_notice_requested"

## Exact NPC incarnation observed by the sensor.
var body_reference: WeakRef
## Actual camera owner observed by the sensor.
var player_reference: WeakRef
## Exact sampled component, invalidated by native reconstruction.
var state: C_NpcStalking
## Exact authored capability captured with that component.
var rule: DEF_NpcStalking
## Brain reset generation captured before publication.
var lifecycle_generation: int
## Exact hidden episode observed; a later episode cannot inherit a queued old notice.
var episode_sequence: int


#region Captured synchronous sample
func _init(body: E_DistrictNpc, player: Entity, sampled: C_NpcStalking) -> void:
	body_reference = weakref(body)
	player_reference = weakref(player)
	state = sampled
	rule = sampled.rule
	lifecycle_generation = (body.get_component(C_NpcDecision) as C_NpcDecision).lifecycle_generation
	episode_sequence = sampled.episode_sequence
#endregion
