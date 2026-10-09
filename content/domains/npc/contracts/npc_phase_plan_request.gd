extends RefCounted
## Explicit assignment of one NPC's calendar goal; placement belongs to the lifecycle handler.
class_name NpcPhasePlanRequest

## Targeted planning command channel.
const EVENT: StringName = &"npc_phase_plan_requested"
## Requested gameplay day, including explicit future-morning preparation.
var day_index: int = 0
## Requested authored calendar phase.
var phase: C_DayCycle.Phase = C_DayCycle.Phase.MORNING
## Allows the preparation boundary to synchronize physical placement once.
var synchronize: bool = false
## Requests reconsideration after a role interruption in the same calendar phase.
var force: bool = false
## Immutable identity reference to the aggregate record captured by the command publisher.
var record_identity: NpcRecord = null
## True only after the actual handler commit or terminal rejection.
var completed: bool = false
## True for committed or duplicate assignment.
var succeeded: bool = false
## Reason-coded terminal rejection.
var rejection_reason: StringName = &""
