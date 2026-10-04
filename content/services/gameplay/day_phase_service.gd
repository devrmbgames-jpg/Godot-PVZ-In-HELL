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
			return cycle.phase == C_DayCycle.Phase.DAY and finish_blockers(cycle).is_empty()

		DayTransitionRequest.Kind.SLEEP:
			return cycle.phase == C_DayCycle.Phase.EVENING and NpcSleepService.blockers().is_empty()
	return false


## The same current facts gate commands, transition commits and readable UI.
static func finish_blockers(cycle: C_DayCycle) -> PackedStringArray:
	var reasons: PackedStringArray = []
	if cycle == null:
		return ["Смена недоступна"]

	var flow: C_CustomerFlow = CustomerFlowService.current()
	var unfinished: int = CustomerFlowService.actionable_remaining(flow, cycle.day_index) if flow != null else cycle.remaining_customer_events
	if cycle.require_finished_customers and unfinished > 0:
		reasons.append("Завершить визиты: %d" % unfinished)
	if cycle.minimum_shift_seconds > cycle.shift_elapsed_seconds:
		reasons.append("До конца смены: %.0f с" % ceilf(cycle.minimum_shift_seconds - cycle.shift_elapsed_seconds))
	if cycle.require_empty_customer_room:
		var inside: int = customers_in_room(cycle)
		if inside < 0:
			reasons.append("Не настроена зона посетителей")
		elif inside > 0:
			reasons.append("Посетителей в здании: %d" % inside)
	if cycle.require_all_planned_arrivals and flow == null:
		reasons.append("Не настроен план посетителей")
	elif cycle.require_all_planned_arrivals:
		var unarrived: int = 0
		for visit: CustomerVisit in flow.visits:
			if visit.arrival_day <= cycle.day_index and not visit.started and not visit.finished:
				unarrived += 1
		if unarrived > 0:
			reasons.append("Ожидаются запланированные клиенты: %d" % unarrived)
	return reasons


static func customers_in_room(cycle: C_DayCycle) -> int:
	if not is_instance_valid(ECS.world):
		return 0 if cycle.customer_room_path.is_empty() else -1

	var room: Area3D = null
	if not cycle.customer_room_path.is_empty():
		var owner: Entity = ECS.world.query.with_all([C_DayCycle]).execute_one()
		room = owner.get_node_or_null(cycle.customer_room_path) as Area3D if owner != null else null
		if room == null or not room.is_inside_tree() or not room.monitoring:
			return -1

	var count: int = 0
	for customer: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var body: Node3D = customer as Node as Node3D
		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
		if visit != null and visit.finished:
			continue
		if not customer.has_component(C_Death) and (room == null or (body != null and room.overlaps_body(body))):
			count += 1
	return count


static func shift_status(cycle: C_DayCycle) -> String:
	if cycle == null:
		return ""
	if cycle.phase == C_DayCycle.Phase.EVENING:
		var sleep_reasons: PackedStringArray = NpcSleepService.blockers()
		return "Сон доступен" if sleep_reasons.is_empty() else "Сон: " + " · ".join(sleep_reasons)
	if cycle.phase != C_DayCycle.Phase.DAY:
		return ""

	var reasons: PackedStringArray = finish_blockers(cycle)
	return "Смена %.0f с · %s" % [floorf(cycle.shift_elapsed_seconds), "Завершение доступно" if reasons.is_empty() else " · ".join(reasons)]


static func submit(request: DayTransitionRequest) -> bool:
	var cycle: C_DayCycle = current()
	if request == null or not permits(cycle, request.kind):
		return false
	if request.expected_day != cycle.day_index or request.expected_phase != cycle.phase:
		return false

	cycle.pending_transition = request
	return true
