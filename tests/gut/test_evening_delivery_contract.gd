extends "res://tests/gut/test_district_delivery_offers.gd"
## Native offer deadlines and evening obligations share persisted jobs and schedule execution.

const SERVICE_TREE: String = "res://content/domains/customers/ai/trees/bt_npc_service.tres"
const SCHEDULE_TREE: String = "res://content/domains/npc/ai/trees/bt_npc_schedule.tres"

var _intent_system: S_NpcIntent = null


func before_each() -> void:
	super.before_each()
	_intent_system = S_NpcIntent.new()
	_world.add_system(_intent_system)


#region Calendar and presentation fixtures
func _published_info(visit: CustomerVisit) -> TerminalDeliveryInfo:
	var visits: Dictionary[String, CustomerVisit] = { visit.package_id: visit }
	var ledger: C_PackageLedger = PackageQueries.ledger()
	var rows: Dictionary[String, TerminalDeliveryInfo] = HomeDeliveryQueries.published_by_package(
		ledger,
		PackageQueries.live_states(),
		visits,
	)
	return rows.get(visit.package_id) as TerminalDeliveryInfo


func _terminal_case(suffix: String, collection: int = 3) -> CustomerVisit:
	_district.definition.personal_delivery_daily_minimum = 0
	return _delivery_case(_district.people[0], suffix, collection)


func _evening() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.EVENING
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	_world.emit_event(DayPhaseChanged.EVENT, session, DayPhaseChanged.from_cycle(cycle))


func _assert_waiting(person: NpcRecord) -> void:
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	assert_eq(person.goal_id, person.home_id)
	assert_eq(person.placement, NpcRecord.Placement.STREET)
	assert_true(body.enabled)
	assert_false(body.has_component(C_CustomerAgent))
	body.place_at(NpcPopulationQueries.position_for(person.home_id) + Vector3.RIGHT * 5.0)
	assert_true(_run_tree(body, SCHEDULE_TREE, 0.2))
	var intent: C_NpcIntent = body.get_component(C_NpcIntent) as C_NpcIntent
	assert_eq(intent.move_position, NpcPopulationQueries.position_for(person.home_id))
	body.place_at(intent.move_position)
	assert_true(_run_tree(body, SCHEDULE_TREE, 0.2))
	assert_true(person.phase_complete)
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	var generation: int = decision.action_generation
	var sequence: int = person.activity_sequence
	for step: int in range(4):
		assert_true(_run_tree(body, SCHEDULE_TREE, 0.2))
		assert_false(intent.movement_active)
		assert_eq(decision.action_generation, generation)
		assert_eq(person.activity_sequence, sequence)
	assert_eq(person.placement, NpcRecord.Placement.STREET)
	assert_true(NpcHomeDeliveryService.knock(_player, _door(person.home_id)))
	_world.process(0.016)
	assert_true(_run_tree(body, SERVICE_TREE, 0.2))
	var role: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(role.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
#endregion


#region Collection boundary
func test_terminal_offer_survives_prior_night_and_closes_on_collection_day() -> void:
	var visit: CustomerVisit = _terminal_case("window")
	var job: NpcHomeDelivery = _job(visit)
	assert_not_null(job)
	assert_eq(job.source, NpcHomeDelivery.Source.TERMINAL)
	assert_true(HomeDeliveryQueries.available(job))
	assert_true(_published_info(visit).can_respond)
	assert_true(NpcHomeDeliveryService.finish_evening(1))
	assert_eq(job.status, NpcHomeDelivery.Status.OFFERED)
	_next_day()
	assert_true(HomeDeliveryQueries.available(job))
	assert_true(_published_info(visit).can_respond)
	assert_eq(HomeDeliveryQueries.terminal_offers().size(), 1)
	assert_true(NpcHomeDeliveryService.finish_evening(2))
	assert_eq(job.status, NpcHomeDelivery.Status.EXPIRED)
	_next_day()
	assert_false(HomeDeliveryQueries.available(job))
	assert_false(_published_info(visit).can_respond)
	assert_eq(HomeDeliveryQueries.terminal_offers().size(), 0)
	assert_false(NpcDeliveryOfferService.respond_published(job.job_id, true))
	assert_false(visit.started)
	assert_eq(visit.arrival_day, 3)


func test_same_day_registration_never_creates_terminal_delivery_action() -> void:
	var visit: CustomerVisit = _terminal_case("today", 1)
	assert_null(_job(visit))
	assert_eq(HomeDeliveryQueries.terminal_offers().size(), 0)
	assert_null(_published_info(visit))
	assert_false(visit.finished)


func test_stale_terminal_action_is_rejected_without_expiry_processing() -> void:
	var visit: CustomerVisit = _terminal_case("stale")
	var job: NpcHomeDelivery = _job(visit)
	DayPhaseQueries.current().day_index = 3
	assert_eq(job.status, NpcHomeDelivery.Status.OFFERED)
	assert_false(_published_info(visit).can_respond)
	assert_false(NpcDeliveryOfferService.respond_published(job.job_id, true))
	assert_eq(job.status, NpcHomeDelivery.Status.OFFERED)
	assert_eq(visit.next_followup_day, 0)


func test_later_acceptance_uses_that_evening_and_preserves_job_identity() -> void:
	var visit: CustomerVisit = _terminal_case("later")
	var job: NpcHomeDelivery = _job(visit)
	var identity: StringName = job.job_id
	_next_day()
	assert_true(NpcDeliveryOfferService.respond_published(identity, true))
	assert_eq(job.job_id, identity)
	assert_eq(job.day_index, 2)
	assert_eq(job.deadline_day, 3)
	assert_eq(visit.next_followup_day, 3)
	assert_same(HomeMeetingQueries.job_for_address(job.address_id), job)
	_assert_waiting(NpcPopulationQueries.person_for(job.npc_id))


## Actual early refusal, rather than the future pickup plan, controls the morning return.
func test_early_terminal_home_refusal_can_return_next_morning() -> void:
	var visit: CustomerVisit = _terminal_case("early_refusal")
	var job: NpcHomeDelivery = _job(visit)
	assert_true(NpcDeliveryOfferService.respond_published(job.job_id, true))
	_assert_waiting(NpcPopulationQueries.person_for(job.npc_id))
	visit.definition.voluntary_refusal = true
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(job.npc_id)
	var parcel: Entity = PackageQueries.find_live_package(visit.package_id)
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _player))
	assert_eq(
		CustomerFlowService.confirm_direct_delivery(_player, body),
		PackageDeliveryCheck.Result.READY,
	)
	assert_eq(visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)
	assert_true(NpcHomeDeliveryService.complete(job))
	assert_eq(job.status, NpcHomeDelivery.Status.REFUSED)
	assert_eq(visit.arrival_day, 3)
	assert_eq(visit.last_visit_day, 1)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.MORNING
	assert_true(PackageReturnService.can_return(parcel))
	assert_eq(WalletService.current().operations.size(), 0)
#endregion


#region Evening arrival and durable identity
func test_personal_acceptance_in_day_routes_home_at_evening_before_knock() -> void:
	DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "personal_wait")
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	assert_true(NpcHomeDeliveryService.accept(body))
	assert_eq(_job(visit).source, NpcHomeDelivery.Source.PERSONAL)
	_evening()
	_assert_waiting(person)


func test_terminal_acceptance_overrides_completed_evening_wander_and_survives_codec() -> void:
	var visit: CustomerVisit = _terminal_case("terminal_wait")
	var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
	person.phase_complete = true
	var job: NpcHomeDelivery = _job(visit)
	assert_true(NpcDeliveryOfferService.respond_published(job.job_id, true))
	assert_false(person.phase_complete)
	_district.definition = load(_district_definition_path()) as DEF_District
	var fields: Dictionary = SaveDataCodec.component_data(_district).fields as Dictionary
	var restored: C_District = C_District.new()
	assert_true(SaveDataCodec.apply_fields(restored, fields))
	var restored_person: NpcRecord = null
	for candidate: NpcRecord in restored.people:
		if candidate.npc_id == person.npc_id:
			restored_person = candidate
	assert_not_null(restored_person)
	assert_true(
		NpcScheduleRules.waiting_at_home(restored, restored_person, 1, C_DayCycle.Phase.EVENING)
	)
	_assert_waiting(person)
#endregion
