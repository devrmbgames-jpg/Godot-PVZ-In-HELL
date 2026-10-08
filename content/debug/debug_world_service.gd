extends RefCounted
## QA-входы в обычные сервисы фаз дня и очереди обслуживания.
class_name DebugWorldService


## Запрашивает следующий допустимый переход фазы через DayPhaseService; ночь не переключает вручную.
static func day_next() -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if cycle == null:
		result.message = "day cycle is unavailable"
		return result
	if cycle.pending_transition != null:
		result.message = "a day transition is already pending"
		return result
	if cycle.phase == C_DayCycle.Phase.NIGHT:
		result.message = "Night advances automatically when night_ready is true"
		return result

	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	match cycle.phase:
		C_DayCycle.Phase.MORNING:
			request.kind = DayTransitionRequest.Kind.START_SHIFT
		C_DayCycle.Phase.DAY:
			request.kind = DayTransitionRequest.Kind.FINISH_SHIFT
		C_DayCycle.Phase.EVENING:
			request.kind = DayTransitionRequest.Kind.SLEEP
		_:
			result.message = "unsupported current phase"
			return result

	if not DayPhaseService.submit(request):
		result.message = "DayPhaseService rejected transition"
		if cycle.phase == C_DayCycle.Phase.MORNING:
			result.details.append_array(DayPhaseService.start_blockers(cycle))
		elif cycle.phase == C_DayCycle.Phase.DAY:
			result.details.append_array(DayPhaseService.finish_blockers(cycle))
		return result

	result.success = true
	result.message = "day transition queued"
	result.details.append("day=%d" % cycle.day_index)
	result.details.append(
		"phase=%s" % String(C_DayCycle.Phase.keys()[cycle.phase])
	)
	result.details.append(
		"kind=%s" % String(DayTransitionRequest.Kind.keys()[request.kind])
	)
	return result


## В дневную фазу запрашивает следующую доступную задачу обслуживания при свободной активной роли.
static func customer_next() -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if flow == null or cycle == null:
		result.message = "customer flow/day cycle is unavailable"
		return result
	if cycle.phase != C_DayCycle.Phase.DAY:
		result.message = "customer_next requires DAY phase"
		return result
	if not ECS.world.query.with_all([C_CustomerAgent]).execute().is_empty():
		result.message = "a live Customer is already active"
		return result

	var wallet: C_Wallet = WalletService.current()
	var payment: int = (
		wallet.policy.delivery_payment
		if wallet != null and wallet.policy != null
		else 0
	)
	var planning: CustomerPlanningRequest = CustomerPlanningRequest.new()
	planning.flow = flow
	planning.day_index = cycle.day_index
	planning.payment = payment
	var session: Entity = ECS.world.query.with_all([C_CustomerFlow, C_DayCycle]).execute_one()
	ECS.world.emit_event(CustomerPlanningRequest.EVENT, session, planning)
	if not planning.completed or not planning.rejection_reason.is_empty():
		result.message = "customer planning is pending"
		return result

	var started: bool = false
	if NpcPopulationQueries.current() != null:
		started = NpcServiceRole.enqueue_next(flow, cycle)
	else:
		var visit: CustomerVisit = CustomerFlowQueries.next_arrival(flow, cycle)
		if visit != null:
			CustomerFlowService.start_visit(flow, visit, cycle.day_index)
			started = true
	if not started:
		result.message = "no due unstarted CustomerVisit"
		return result

	var customer: E_NpcCharacter = (
		ECS.world.query.with_all([C_CustomerAgent]).execute_one() as E_NpcCharacter
	)
	result.success = true
	result.message = "next due Customer started"
	if customer != null:
		var agent: C_CustomerAgent = (
			customer.get_component(C_CustomerAgent) as C_CustomerAgent
		)
		if agent != null:
			result.details.append("visit=%s" % String(agent.visit_id))
	return result
