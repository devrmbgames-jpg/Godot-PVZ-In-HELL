extends RefCounted
## Query/command boundary for day-cycle state. S_DayPhase only processes transitions.
class_name DayPhaseService


static func current() -> C_DayCycle:
	if not is_instance_valid(ECS.world):
		return null
	var session: Entity = ECS.world.query.with_all([C_DayCycle]).execute_one()
	return session.get_component(C_DayCycle) as C_DayCycle if session != null else null


static func permits(cycle: C_DayCycle, kind: DayTransitionRequest.Kind) -> bool:
	if cycle == null or cycle.pending_transition != null:
		return false
	match kind:
		DayTransitionRequest.Kind.START_SHIFT:
			return cycle.phase == C_DayCycle.Phase.MORNING
		DayTransitionRequest.Kind.FINISH_SHIFT:
			return cycle.phase == C_DayCycle.Phase.DAY and cycle.remaining_customer_events == 0
		DayTransitionRequest.Kind.SLEEP:
			return cycle.phase == C_DayCycle.Phase.EVENING
	return false


static func submit(request: DayTransitionRequest) -> bool:
	var cycle: C_DayCycle = current()
	if request == null or not permits(cycle, request.kind):
		return false
	if request.expected_day != cycle.day_index or request.expected_phase != cycle.phase:
		return false
	cycle.pending_transition = request
	return true
