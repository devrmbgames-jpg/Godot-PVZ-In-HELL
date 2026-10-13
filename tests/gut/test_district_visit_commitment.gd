extends "res://tests/gut/test_district_service_queue.gd"
## Same-day visit plans survive temporary avoidance; only a called service approach can defer.


#region Native plan and interruption regressions
func test_six_planned_recipients_reach_counter_after_temporary_avoidance() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	_district.definition.service_transfer_pause = 0.0
	_world.add_system(S_NpcIntent.new())
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = DEF_CustomerSchedule.new()
	var bodies: Array[E_DistrictNpc] = []
	var visits: Array[CustomerVisit] = []
	for index: int in 6:
		var body: E_DistrictNpc = _stage(index)
		bodies.append(body)
		var visit: CustomerVisit = _case(_district.people[index], "commitment_%d" % index)
		visit.definition = visit.definition.duplicate() as DEF_Customer
		visit.definition.voluntary_refusal = false
		visits.append(visit)
		(body.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing = index % 2 == 0
	for attempt: int in 3:
		assert_true(NpcServiceRole.enqueue_next(flow, cycle))
	assert_eq(CustomerFlowQueries.actionable_remaining(flow, 1), 6)
	assert_false(DayPhaseService.finish_blockers(cycle).is_empty())
	for visit: CustomerVisit in visits:
		assert_eq(visit.deferred_day, 0)
		assert_false(visit.finished)

	var interruption: NpcRoleInterruptionRequest = NpcRoleInterruptionRequest.new()
	_world.emit_event(NpcRoleInterruptionRequest.EVENT, bodies[1], interruption)
	assert_true(interruption.handled)
	assert_false(bodies[1].has_component(C_CustomerAgent))
	assert_eq(CustomerFlowQueries.actionable_remaining(flow, 1), 6)
	for body: E_DistrictNpc in bodies:
		(body.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing = false

	var arrivals: int = 0
	for attempt: int in 6:
		for preparation: int in 3:
			NpcServiceRole.enqueue_next(flow, cycle)
		var called: E_DistrictNpc = null
		for body: E_DistrictNpc in bodies:
			if body.has_component(C_CustomerAgent) and NpcServiceRole.can_approach(body):
				called = body
				break
		assert_not_null(called, "All six retained same-day plans eventually obtain their turn")
		if called == null:
			return
		_run_branch(called, C_NpcDecision.Owner.SERVICE, 0.2)
		assert_eq(
			(called.get_component(C_CustomerAgent) as C_CustomerAgent).phase,
			C_CustomerAgent.Phase.APPROACHING,
		)
		called.place_at(CustomerFlowQueries.counter().waiting_position())
		_world.process(0.0)
		_run_branch(called, C_NpcDecision.Owner.SERVICE, 0.2)
		assert_eq(
			(called.get_component(C_CustomerAgent) as C_CustomerAgent).phase,
			C_CustomerAgent.Phase.WAITING,
		)
		arrivals += 1
		var visit: CustomerVisit = CustomerFlowQueries.visit_for(called)
		var package: C_Package = C_Package.new()
		package.package_id = visit.package_id
		var state: C_PackageState = C_PackageState.new()
		state.registration = C_PackageState.Registration.REGISTERED
		var delivery_check: PackageDeliveryCheck = CustomerOutcomeService.check(
			visit,
			package,
			state,
			true,
			false,
		)
		assert_true(CustomerOutcomeService.receive(visit, delivery_check))
		NpcServiceRole.finish_appearance(called, visit)
	assert_eq(arrivals, 6)
	assert_eq(CustomerFlowQueries.actionable_remaining(flow, 1), 0)
	for visit: CustomerVisit in visits:
		assert_eq(visit.actual, CustomerVisit.Actual.DELIVERED)
		assert_eq(visit.deferred_day, 0)
		assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)
		assert_false(visit.settlement_committed)


func test_blocked_waiting_routes_do_not_defer_but_called_approach_does() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var first_body: E_DistrictNpc = _stage(0)
	var next_body: E_DistrictNpc = _stage(3)
	var first: CustomerVisit = _case(_district.people[0], "blocked_front")
	var next: CustomerVisit = _case(_district.people[3], "blocked_waiting")
	NpcServiceRole.begin(first_body, _district.people[0], first, 1)
	NpcServiceRole.begin(next_body, _district.people[3], next, 1)
	for body: E_DistrictNpc in [first_body, next_body]:
		var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
		decision.intent_owner = C_NpcDecision.Owner.SERVICE
		var waiting: NpcRoleInterruptionRequest = NpcRoleInterruptionRequest.new(
			NpcRoleInterruptionRequest.Kind.ROUTE_BLOCKED
		)
		_world.emit_event(NpcRoleInterruptionRequest.EVENT, body, waiting)
		assert_true(waiting.handled)
		assert_true(body.has_component(C_CustomerAgent))
	assert_eq(first.deferred_day, 0)
	assert_eq(next.deferred_day, 0)
	_run_branch(first_body, C_NpcDecision.Owner.SERVICE, 0.2)
	assert_eq(
		(first_body.get_component(C_CustomerAgent) as C_CustomerAgent).phase,
		C_CustomerAgent.Phase.APPROACHING,
	)
	var blocked: NpcRoleInterruptionRequest = NpcRoleInterruptionRequest.new(
		NpcRoleInterruptionRequest.Kind.ROUTE_BLOCKED
	)
	_world.emit_event(NpcRoleInterruptionRequest.EVENT, first_body, blocked)
	assert_true(blocked.handled)
	assert_false(first_body.has_component(C_CustomerAgent))
	assert_eq(first.deferred_day, 1)
	assert_eq(first.defer_reason, "Путь к ПВЗ недоступен")
	assert_eq(first.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(first.declaration, CustomerVisit.Declaration.NONE)
	assert_false(first.settlement_committed)
	assert_eq(next.deferred_day, 0)
	assert_true(NpcServiceRole.can_approach(next_body))


func test_emergency_route_failure_keeps_called_order_due_today() -> void:
	DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY
	var body: E_DistrictNpc = _stage(0)
	var visit: CustomerVisit = _case(_district.people[0], "emergency_route")
	NpcServiceRole.begin(body, _district.people[0], visit, 1)
	NpcServiceRole.claim_counter(body)
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	decision.intent_owner = C_NpcDecision.Owner.EMERGENCY
	var blocked: NpcRoleInterruptionRequest = NpcRoleInterruptionRequest.new(
		NpcRoleInterruptionRequest.Kind.ROUTE_BLOCKED
	)
	_world.emit_event(NpcRoleInterruptionRequest.EVENT, body, blocked)
	assert_eq(visit.deferred_day, 0)
	assert_true(body.has_component(C_CustomerAgent))
	_world.emit_event(NpcRoleInterruptionRequest.EVENT, body, NpcRoleInterruptionRequest.new())
	assert_false(body.has_component(C_CustomerAgent))
	assert_false(visit.started)
	assert_false(visit.finished)
	assert_eq(visit.deferred_day, 0)
	assert_eq(CustomerFlowQueries.actionable_remaining(CustomerFlowQueries.current(), 1), 1)
	assert_true(
		NpcServiceRole.enqueue_next(CustomerFlowQueries.current(), DayPhaseQueries.current())
	)


func test_flee_exit_releases_execution_without_closing_the_planned_visit() -> void:
	DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY
	var body: E_DistrictNpc = _stage(0)
	var visit: CustomerVisit = _case(_district.people[0], "flee_exit_plan")
	NpcServiceRole.begin(body, _district.people[0], visit, 1)
	var exiting: NpcRoleInterruptionRequest = NpcRoleInterruptionRequest.new(
		NpcRoleInterruptionRequest.Kind.FLEE_EXIT
	)
	_world.emit_event(NpcRoleInterruptionRequest.EVENT, body, exiting)
	assert_true(exiting.handled)
	assert_false(body.has_component(C_CustomerAgent))
	assert_false(visit.started)
	assert_false(visit.finished)
	assert_eq(visit.deferred_day, 0)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_false(DayPhaseService.finish_blockers(DayPhaseQueries.current()).is_empty())
#endregion
