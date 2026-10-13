extends RefCounted
## Explicit schedule execution operations over C_NpcDecision; no selection or scheduled tick.
class_name NpcScheduleActionService


#region Schedule completion requests
## Captures one goal's identity and submits its requested completion participation.
## Authored completion is the default; explicit escape/skip commands may supply placement.
static func request_phase_completion(
	body: E_DistrictNpc,
	placement: int = -1,
) -> NpcScheduleCompletionRequest:
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	var request: NpcScheduleCompletionRequest = NpcScheduleCompletionRequest.new()
	request.planned_day = person.planned_day
	request.planned_phase = person.planned_phase
	request.goal_id = person.goal_id
	request.record_identity = person
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	request.decision_owner = decision.intent_owner
	request.decision_identity = decision
	if (
		decision.intent_owner == C_NpcDecision.Owner.SCHEDULE
		and decision.action_status
		in [C_NpcDecision.ActionStatus.ACCEPTED, C_NpcDecision.ActionStatus.RUNNING]
	):
		request.action_generation = decision.action_generation
	request.placement = (
		NpcScheduleRules.completed_placement(
			person,
			NpcScheduleRules.waiting_at_home(
				NpcPopulationQueries.current(),
				person,
				person.planned_day,
				person.planned_phase as C_DayCycle.Phase,
			),
		)
		if placement < 0
		else placement as NpcRecord.Placement
	)
	ECS.world.emit_event(NpcScheduleCompletionRequest.EVENT, body, request)
	return request
#endregion


#region Schedule execution operations
## Accepts the existing authored obligation once; move/finish adapters share its identity.
static func accept_schedule(actor: E_DistrictNpc, person: NpcRecord) -> int:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	var same_goal: bool = (
		decision.action_goal_id == person.goal_id and decision.action_day == person.planned_day
		and decision.action_phase == person.planned_phase
	)
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
	decision.action_status = (
		C_NpcDecision.ActionStatus.COMPLETED if succeeded else C_NpcDecision.ActionStatus.FAILED
	)
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
