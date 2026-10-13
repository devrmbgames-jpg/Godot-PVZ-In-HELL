extends "res://tests/gut/test_district_plan_acceptance.gd"
## A captured smoke query must survive native light-role retirement during another handoff.


class CounterFixture extends "res://tests/smoke/district_release_smoke.gd":
	## Runs the native role transition while the expensive handoff boundary is suspended.
	var handoff: Callable
	## Visits whose asynchronous handoff started.
	var issued_visits: Array[StringName] = []
	## Visits reaching the isolated terminal boundary.
	var reported_visits: Array[StringName] = []


	func _ready() -> void:
		pass


	func _give_box(
		body: E_DistrictNpc,
		visit: CustomerVisit,
		_refused: bool = false,
		_watch_light: bool = false,
	) -> void:
		issued_visits.append(visit.visit_id)
		await get_tree().physics_frame
		handoff.call(body, visit)


	func _report_counter_delivery(visit: CustomerVisit) -> void:
		reported_visits.append(visit.visit_id)


	## Executes the actual smoke traversal using the isolated native district fixture.
	func serve(flow: C_CustomerFlow, cycle: C_DayCycle) -> bool:
		_flow = flow
		_cycle = cycle
		await _serve_counter(cycle.day_index, false)
		return not _failed


func test_counter_skips_native_light_role_released_during_awaited_handoff() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.DAY
	var first_body: E_DistrictNpc = _stage(0)
	var waiting_body: E_DistrictNpc = _stage(6)
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	_district.people[6].profile.rules = [rule]
	_light_zone()
	var first: CustomerVisit = _case(_district.people[0], "async_first")
	first.definition = first.definition.duplicate() as DEF_Customer
	first.definition.voluntary_refusal = false
	var waiting: CustomerVisit = _case(_district.people[6], "async_light_wait")
	NpcServiceRole.begin(first_body, _district.people[0], first, 2)
	(first_body.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent \
			.Phase.WAITING_FOR_PACKAGE
	NpcServiceRole.begin(waiting_body, _district.people[6], waiting, 2)
	# Queue priority and captured GECS iteration order are independent fixture inputs.
	first.queue_order = waiting.queue_order + 1
	NpcServiceRole.claim_counter(waiting_body)
	waiting_body.place_at(CustomerFlowQueries.counter().entry_position())
	_run_branch(waiting_body, C_NpcDecision.Owner.SERVICE, 0.2)
	var service: C_CustomerAgent = waiting_body.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_true(service.light_warning_started)
	if not service.light_warning_started:
		return
	assert_eq(_world.query.with_all([C_CustomerAgent]).execute(), [first_body, waiting_body])

	var fixture: CounterFixture = CounterFixture.new()
	_root.add_child(fixture)
	fixture.handoff = func(body: E_DistrictNpc, visit: CustomerVisit) -> void:
		service.entrance_wait_elapsed = _district.definition.service_wait_timeout
		_run_branch(waiting_body, C_NpcDecision.Owner.SERVICE, 0.2)
		var package: C_Package = C_Package.new()
		package.package_id = visit.package_id
		var state: C_PackageState = C_PackageState.new()
		state.registration = C_PackageState.Registration.REGISTERED
		var checked: PackageDeliveryCheck = CustomerOutcomeService.check(
			visit,
			package,
			state,
			true,
			false,
		)
		assert_true(CustomerOutcomeService.receive(visit, checked))
		NpcServiceRole.finish_appearance(body, visit)
	assert_true(
		await fixture.serve(CustomerFlowQueries.current(), cycle),
		"The actual smoke loop completes after the awaited role removal",
	)
	assert_eq(fixture.issued_visits, [first.visit_id])
	assert_eq(fixture.reported_visits, [first.visit_id])
	assert_false(waiting_body.has_component(C_CustomerAgent))
	assert_eq(waiting.deferred_day, 2)
	assert_eq(waiting.next_followup_day, 3)
	assert_eq(waiting.defer_reason, fixture.LIGHT_TIMEOUT_REASON)
	assert_eq(waiting.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(waiting.declaration, CustomerVisit.Declaration.NONE)
	assert_false(waiting.settlement_committed)
	assert_eq(waiting.money_delta, 0)
	assert_eq(waiting.disposition, CustomerVisit.Disposition.WAREHOUSE)
	assert_true(DayPhaseService.finish_blockers(cycle).is_empty())
