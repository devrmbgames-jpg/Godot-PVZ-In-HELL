extends RefCounted
## Explicit schedule execution operations over C_NpcDecision; no selection or scheduled tick.
class_name NpcScheduleActionService


#region Schedule execution operations
## Accepts the existing authored obligation once; move/finish adapters share its identity.
static func accept_schedule(actor: E_DistrictNpc, person: NpcRecord) -> int:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	var same_goal: bool = decision.action_goal_id == person.goal_id \
			and decision.action_day == person.planned_day \
			and decision.action_phase == person.planned_phase
	if (
		same_goal
		and decision.action_status
		in [C_NpcDecision.ActionStatus.ACCEPTED, C_NpcDecision.ActionStatus.RUNNING]
	):
		return decision.action_generation
	cancel_schedule(actor, &"obligation_replaced")
	decision.action_generation += 1
	decision.action_goal_id = person.goal_id
	decision.action_day = person.planned_day
	decision.action_phase = person.planned_phase
	decision.action_status = C_NpcDecision.ActionStatus.ACCEPTED
	decision.action_reason = &"accepted_obligation"
	return decision.action_generation


## Starts only the accepted incarnation; stale adapters cannot resume a replacement.
static func start_schedule(actor: E_DistrictNpc, generation: int) -> bool:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision.action_generation != generation:
		return false
	if decision.action_status == C_NpcDecision.ActionStatus.ACCEPTED:
		decision.action_status = C_NpcDecision.ActionStatus.RUNNING
		decision.action_reason = &"executing_obligation"
	return decision.action_status == C_NpcDecision.ActionStatus.RUNNING


## Commits a terminal result for the captured running incarnation only.
static func finish_schedule(
	actor: E_DistrictNpc,
	generation: int,
	succeeded: bool,
	reason: StringName,
) -> void:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if (
		decision.action_generation != generation
		or decision.action_status
		not in [C_NpcDecision.ActionStatus.ACCEPTED, C_NpcDecision.ActionStatus.RUNNING]
	):
		return
	decision.action_status = C_NpcDecision.ActionStatus.COMPLETED if succeeded \
			else C_NpcDecision.ActionStatus.FAILED
	decision.action_reason = reason
	_release_schedule_intent(actor, decision)


## Cancels execution without completing or replacing the mandatory schedule obligation.
static func cancel_schedule(actor: E_DistrictNpc, reason: StringName) -> void:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	if decision.action_status not in [
		C_NpcDecision.ActionStatus.ACCEPTED,
		C_NpcDecision.ActionStatus.RUNNING,
	]:
		return
	decision.action_status = C_NpcDecision.ActionStatus.CANCELLED
	decision.action_reason = reason
	_release_schedule_intent(actor, decision)


## Reports unavailable authored targets instead of treating the origin as a destination.
static func schedule_target_available(person: NpcRecord) -> bool:
	return NpcPopulationQueries.current().definition.place_for(person.goal_id) != null


static func _release_schedule_intent(actor: E_DistrictNpc, decision: C_NpcDecision) -> void:
	if decision.intent_owner in [C_NpcDecision.Owner.SCHEDULE, C_NpcDecision.Owner.NONE]:
		NpcIntentService.stop(actor)
		decision.active_task_id = 0
#endregion
