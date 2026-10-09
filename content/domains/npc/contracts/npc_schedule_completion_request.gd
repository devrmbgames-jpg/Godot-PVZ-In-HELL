extends RefCounted
## Requests completion of a captured macro goal; stale queued decisions cannot finish its replacement.
class_name NpcScheduleCompletionRequest

## Sole-handler completion command channel.
const EVENT: StringName = &"npc_schedule_completion_requested"
## Captured goal day at dispatch.
var planned_day: int = 0
## Captured goal phase at dispatch.
var planned_phase: int = -1
## Captured authored destination identity at dispatch.
var goal_id: StringName = &""
## Requested physical participation after completing the goal.
var placement: NpcRecord.Placement = NpcRecord.Placement.STREET
## Aggregate record identity; replacement/restore cannot complete an older record's command.
var record_identity: NpcRecord = null
## Captured decision owner; NONE permits an explicit operation outside a running BT branch.
var decision_owner: C_NpcDecision.Owner = C_NpcDecision.Owner.NONE
## Exact execution Component at dispatch; reset/replacement rejects old action receipts.
var decision_identity: C_NpcDecision = null
## Captured action incarnation, or zero for an explicit escape/skip operation.
var action_generation: int = 0
## Receipt becomes terminal only at actual commit or rejection.
var completed: bool = false
## True for committed or duplicate completion.
var succeeded: bool = false
## Explicit stale/lifecycle rejection reason.
var rejection_reason: StringName = &""
