extends GutTest

var _world: World = null


func after_each() -> void:
	if is_instance_valid(_world):
		_world.free()
	_world = null
	ECS.world = null


func _visit() -> CustomerVisit:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"visit/shipment1"
	visit.package_id = "shipment1"
	visit.customer_id = &"customer1"
	visit.definition = DEF_Customer.new()
	visit.accounting_value = 100
	visit.payment = 100
	visit.started = true
	return visit


func _ready_check() -> PackageDeliveryCheck:
	var check_result: PackageDeliveryCheck = PackageDeliveryCheck.new()
	check_result.result = PackageDeliveryCheck.Result.READY
	return check_result


func _complaint_visit(actual: CustomerVisit.Actual) -> CustomerVisit:
	var visit: CustomerVisit = _visit()
	visit.actual = actual
	visit.finished = true
	visit.complaint_roll = 0.0
	CustomerOutcomeService.create_complaint(visit, 1)
	return visit


func test_delivery_requires_registration_identity_assignment_and_released_box() -> void:
	var visit: CustomerVisit = _visit()
	var package: C_Package = C_Package.new()
	package.package_id = "shipment1"
	var state: C_PackageState = C_PackageState.new()
	assert_eq(CustomerOutcomeService.check(visit, null, null, false, false).result, PackageDeliveryCheck.Result.MISSING)
	assert_eq(CustomerOutcomeService.check(visit, package, state, true, false).result, PackageDeliveryCheck.Result.UNREGISTERED)
	state.registration = C_PackageState.Registration.REGISTERED
	package.package_id = "different_shipment_with_same_display_number"
	state.registration_number = 1
	assert_eq(CustomerOutcomeService.check(visit, package, state, true, false).result, PackageDeliveryCheck.Result.WRONG_PACKAGE)
	package.package_id = "shipment1"
	assert_eq(CustomerOutcomeService.check(visit, package, state, false, false).result, PackageDeliveryCheck.Result.UNASSIGNED)
	assert_eq(CustomerOutcomeService.check(visit, package, state, true, true).result, PackageDeliveryCheck.Result.HELD)
	state.damage = C_PackageState.Damage.DESTROYED
	assert_eq(CustomerOutcomeService.check(visit, package, state, true, false).result, PackageDeliveryCheck.Result.DESTROYED)


func test_delivered_fact_and_declaration_are_separate_and_payment_is_once() -> void:
	var visit: CustomerVisit = _visit()
	var wallet: C_Wallet = C_Wallet.new()
	assert_true(CustomerOutcomeService.receive(visit, _ready_check()))
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)
	CustomerOutcomeService.settle(visit, wallet, 1)
	assert_eq(wallet.balance, 0)
	assert_true(CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.TAKEN))
	CustomerOutcomeService.settle(visit, wallet, 1)
	CustomerOutcomeService.settle(visit, wallet, 2)
	assert_eq(wallet.balance, 100)
	assert_eq(wallet.operations.size(), 1)
	assert_false(CustomerOutcomeService.receive(visit, _ready_check()))


func test_damaged_opened_can_be_accepted_with_lower_satisfaction_payment() -> void:
	var visit: CustomerVisit = _visit()
	var check_result: PackageDeliveryCheck = _ready_check()
	check_result.damaged = true
	check_result.opened = true
	assert_true(CustomerOutcomeService.receive(visit, check_result))
	assert_eq(visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_eq(visit.satisfaction, 50)
	CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.TAKEN)
	var wallet: C_Wallet = C_Wallet.new()
	CustomerOutcomeService.settle(visit, wallet, 1)
	assert_eq(wallet.balance, 50)


func test_customer_condition_policy_can_refuse_without_player_denial() -> void:
	for opened: bool in [false, true]:
		var visit: CustomerVisit = _visit()
		visit.definition.accepts_damaged = false
		visit.definition.accepts_opened = false
		var check_result: PackageDeliveryCheck = _ready_check()
		check_result.opened = opened
		check_result.damaged = not opened
		CustomerOutcomeService.receive(visit, check_result)
		assert_eq(visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)
		assert_eq(visit.disposition, CustomerVisit.Disposition.WAREHOUSE)
		CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.REFUSED)
		var wallet: C_Wallet = C_Wallet.new()
		CustomerOutcomeService.settle(visit, wallet, 1)
		assert_eq(wallet.balance, 0)
		assert_eq(visit.reputation, CustomerVisit.Reputation.NONE)


func test_voluntary_refusal_is_authored_even_for_healthy_package() -> void:
	var visit: CustomerVisit = _visit()
	visit.definition.voluntary_refusal = true
	CustomerOutcomeService.receive(visit, _ready_check())
	assert_eq(visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)


func test_lost_and_honest_refusal_have_distinct_costs_and_reputation() -> void:
	var declarations: Array[CustomerVisit.Declaration] = [CustomerVisit.Declaration.LOST, CustomerVisit.Declaration.REFUSED]
	var costs: Array[int] = [120, 150]
	for index: int in declarations.size():
		var visit: CustomerVisit = _visit()
		var wallet: C_Wallet = C_Wallet.new()
		CustomerOutcomeService.declare(visit, declarations[index])
		CustomerOutcomeService.settle(visit, wallet, 1)
		assert_eq(wallet.balance, -costs[index])
		assert_eq(visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
		assert_ne(visit.reputation, CustomerVisit.Reputation.NONE)
		CustomerOutcomeService.settle(visit, wallet, 2)
		assert_eq(wallet.operations.size(), 1)


func test_false_taken_is_legal_and_can_trigger_aggression() -> void:
	var visit: CustomerVisit = _visit()
	visit.aggression_roll = 0.0
	assert_true(CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.TAKEN))
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(visit.declaration, CustomerVisit.Declaration.TAKEN)
	assert_true(visit.aggressive)
	assert_false(CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.LOST))


func test_delayed_complaint_charges_200_once_without_customer_node() -> void:
	var visit: CustomerVisit = _complaint_visit(CustomerVisit.Actual.NOT_RESOLVED)
	CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.TAKEN)
	var wallet: C_Wallet = C_Wallet.new()
	CustomerOutcomeService.resolve_complaint(visit, wallet, 1)
	assert_eq(wallet.balance, 0)
	CustomerOutcomeService.resolve_complaint(visit, wallet, 2)
	CustomerOutcomeService.resolve_complaint(visit, wallet, 10)
	assert_eq(wallet.balance, -200)
	assert_eq(visit.complaint.outcome, CustomerComplaint.Outcome.CONFIRMED)
	assert_eq(visit.reputation, CustomerVisit.Reputation.FRAUD)


func test_concealed_refusal_then_late_declaration_does_not_add_second_penalty() -> void:
	var visit: CustomerVisit = _complaint_visit(CustomerVisit.Actual.NOT_RESOLVED)
	var wallet: C_Wallet = C_Wallet.new()
	CustomerOutcomeService.resolve_complaint(visit, wallet, 2)
	CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.LOST)
	CustomerOutcomeService.settle(visit, wallet, 2)
	assert_eq(wallet.balance, -200)
	assert_eq(wallet.operations.size(), 1)


func test_honest_lost_settlement_does_not_get_duplicate_complaint_charge() -> void:
	var visit: CustomerVisit = _complaint_visit(CustomerVisit.Actual.NOT_RESOLVED)
	var wallet: C_Wallet = C_Wallet.new()
	CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.LOST)
	CustomerOutcomeService.settle(visit, wallet, 1)
	CustomerOutcomeService.resolve_complaint(visit, wallet, 2)
	assert_eq(wallet.balance, -120)
	assert_eq(visit.complaint.outcome, CustomerComplaint.Outcome.ALREADY_SETTLED)


func test_player_defeat_waives_false_taken_fine_but_preserves_reason() -> void:
	var visit: CustomerVisit = _complaint_visit(CustomerVisit.Actual.NOT_RESOLVED)
	CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.TAKEN)
	visit.customer_dead = true
	visit.defeated_by_player = true
	var wallet: C_Wallet = C_Wallet.new()
	CustomerOutcomeService.resolve_complaint(visit, wallet, 2)
	assert_eq(wallet.balance, 0)
	assert_eq(visit.complaint.outcome, CustomerComplaint.Outcome.WAIVED_PLAYER_DEFEAT)
	assert_eq(visit.reputation, CustomerVisit.Reputation.FRAUD)


func test_false_complaint_has_customer_specific_seven_day_window() -> void:
	var visit: CustomerVisit = _complaint_visit(CustomerVisit.Actual.DELIVERED)
	var wallet: C_Wallet = C_Wallet.new()
	CustomerOutcomeService.resolve_complaint(visit, wallet, 2)
	assert_eq(visit.complaint.outcome, CustomerComplaint.Outcome.FALSE_CLAIM)
	assert_false(CustomerOutcomeService.retaliation_allowed(visit, 1))
	assert_true(CustomerOutcomeService.retaliation_allowed(visit, 2))
	assert_true(CustomerOutcomeService.retaliation_allowed(visit, 8))
	assert_false(CustomerOutcomeService.retaliation_allowed(visit, 9))
	assert_false(CustomerOutcomeService.retaliation_allowed(_visit(), 2))
	assert_eq(wallet.balance, 0)


func test_return_does_not_erase_valid_refusal_complaint() -> void:
	var visit: CustomerVisit = _complaint_visit(CustomerVisit.Actual.CUSTOMER_REFUSED)
	visit.disposition = CustomerVisit.Disposition.RETURNED
	var wallet: C_Wallet = C_Wallet.new()
	CustomerOutcomeService.resolve_complaint(visit, wallet, 2)
	assert_eq(wallet.balance, -200)
	assert_eq(visit.complaint.outcome, CustomerComplaint.Outcome.CONFIRMED)


func test_schedule_is_idempotent_has_three_daily_and_ten_day_late_visit() -> void:
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	flow.schedule = load("res://content/definitions/gameplay/customers/def_customer_schedule_default.tres") as DEF_CustomerSchedule
	CustomerFlowService.plan_day(flow, 1, 100)
	CustomerFlowService.plan_day(flow, 1, 100)
	assert_eq(flow.visits.size(), 4)
	assert_eq(CustomerFlowService.remaining(flow, 1), 3)
	assert_eq(flow.visits[3].arrival_day, 11)
	assert_eq(flow.visits[3].package_id, "base_supply:1:equipment")
	for day: int in range(1, 11):
		CustomerFlowService.plan_day(flow, day, 100)
		for visit: CustomerVisit in flow.visits:
			if visit.arrival_day <= day:
				visit.finished = true
	CustomerFlowService.plan_day(flow, 11, 100)
	assert_eq(CustomerFlowService.remaining(flow, 11), 4)
	for visit: CustomerVisit in flow.visits:
		assert_false(visit.package_id.ends_with(":bottles"))


func test_persistent_record_copy_retains_dispute_and_settlement_flags() -> void:
	var visit: CustomerVisit = _complaint_visit(CustomerVisit.Actual.NOT_RESOLVED)
	var wallet: C_Wallet = C_Wallet.new()
	CustomerOutcomeService.resolve_complaint(visit, wallet, 2)
	var restored: CustomerVisit = visit.duplicate(true) as CustomerVisit
	CustomerOutcomeService.resolve_complaint(restored, wallet, 3)
	assert_eq(wallet.operations.size(), 1)
	assert_eq(restored.complaint.outcome, CustomerComplaint.Outcome.CONFIRMED)
	assert_true(restored.settlement_committed)


func _live_fixture() -> CustomerVisit:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var owner: Entity = Entity.new()
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	var visit: CustomerVisit = _visit()
	flow.visits.append(visit)
	owner.component_resources = [flow, C_DayCycle.new(), C_Wallet.new(), C_PackageLedger.new()]
	_world.add_entity(owner)
	return visit


func _live_parcel(visit: CustomerVisit) -> Entity:
	var parcel: Entity = Entity.new()
	var identity: C_Package = C_Package.new()
	identity.package_id = visit.package_id
	var state: C_PackageState = C_PackageState.new()
	state.registration = C_PackageState.Registration.REGISTERED
	parcel.component_resources = [identity, state]
	_world.add_entity(parcel)
	return parcel


func test_live_assignment_is_relationship_and_disappears_with_customer() -> void:
	var visit: CustomerVisit = _live_fixture()
	var parcel: Entity = _live_parcel(visit)
	var customer: Entity = Entity.new()
	_world.add_entity(customer)
	CustomerFlowService.bind_parcel(customer, visit)
	CustomerFlowService.bind_parcel(customer, visit)
	assert_eq(parcel.relationships.size(), 1)
	assert_true(CustomerFlowService.assigned(parcel, customer, visit))
	var impostor: Entity = Entity.new()
	_world.add_entity(impostor)
	assert_false(CustomerFlowService.assigned(parcel, impostor, visit))
	_world.remove_entity(customer)
	assert_true(parcel.relationships.is_empty())
	assert_eq(visit.package_id, "shipment1")


func test_buyout_is_once_keeps_physical_entity_and_releases_number() -> void:
	var visit: CustomerVisit = _live_fixture()
	visit.actual = CustomerVisit.Actual.CUSTOMER_REFUSED
	var parcel: Entity = _live_parcel(visit)
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = visit.package_id
	record.number = 1
	PackageRegistrationService.ledger().records.append(record)
	assert_true(CustomerFlowService.dispose_refusal(visit.visit_id, true))
	assert_false(CustomerFlowService.dispose_refusal(visit.visit_id, true))
	assert_eq(WalletService.current().balance, -100)
	assert_true(is_instance_valid(parcel))
	assert_false(record.active)
	assert_eq(record.departure, C_PackageState.Registration.BOUGHT_OUT)
	assert_eq(visit.disposition, CustomerVisit.Disposition.BOUGHT_OUT)
	assert_eq(PackageRegistrationService.smallest_free_number(PackageRegistrationService.ledger()), 1)


func test_disappeared_customer_finishes_event_without_releasing_package_number() -> void:
	var visit: CustomerVisit = _live_fixture()
	_live_parcel(visit)
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = visit.package_id
	record.number = 1
	PackageRegistrationService.ledger().records.append(record)
	CustomerFlowService.tick(CustomerFlowService.current(), DayPhaseService.current(), 0.0)
	assert_true(visit.finished)
	assert_eq(DayPhaseService.current().remaining_customer_events, 0)
	assert_true(record.active)
	assert_eq(PackageRegistrationService.smallest_free_number(PackageRegistrationService.ledger()), 2)


func test_player_caused_death_finishes_live_event_and_records_attribution() -> void:
	var visit: CustomerVisit = _live_fixture()
	visit.declaration = CustomerVisit.Declaration.TAKEN
	visit.complaint_roll = 0.0
	var actor: Entity = Entity.new()
	actor.component_resources = [C_PlayerInputController.new()]
	_world.add_entity(actor)
	var customer: E_Customer = E_Customer.new()
	var agent: C_CustomerAgent = C_CustomerAgent.new()
	agent.visit_id = visit.visit_id
	customer.component_resources = [agent]
	_world.add_entity(customer)
	var death: C_Death = C_Death.new()
	death.cause = DamageResult.new()
	death.cause.request = DamageRequest.new()
	death.cause.request.instigator = actor
	customer.add_component(death)
	CustomerFlowService.tick(CustomerFlowService.current(), DayPhaseService.current(), 0.0)
	assert_true(visit.finished)
	assert_true(visit.defeated_by_player)
	assert_true(visit.customer_dead)
	assert_eq(DayPhaseService.current().remaining_customer_events, 0)
	CustomerOutcomeService.resolve_complaint(visit, WalletService.current(), 2)
	assert_eq(visit.complaint.outcome, CustomerComplaint.Outcome.WAIVED_PLAYER_DEFEAT)



func test_package_pickup_arrival_waits_for_registration_unless_event_opts_out() -> void:
	var visit: CustomerVisit = _live_fixture()
	visit.started = false
	assert_false(CustomerFlowService.arrival_allowed(visit))
	assert_eq(CustomerFlowService.actionable_remaining(CustomerFlowService.current(), 1), 0)

	visit.requires_registered_package = false
	assert_true(CustomerFlowService.arrival_allowed(visit))
	assert_eq(CustomerFlowService.actionable_remaining(CustomerFlowService.current(), 1), 1)

	visit.requires_registered_package = true
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = visit.package_id
	record.number = 1
	PackageRegistrationService.ledger().records.append(record)
	assert_true(CustomerFlowService.arrival_allowed(visit))
	assert_eq(CustomerFlowService.actionable_remaining(CustomerFlowService.current(), 1), 1)


func test_next_morning_auto_loses_due_unregistered_visit_without_npc_once() -> void:
	var visit: CustomerVisit = _live_fixture()
	visit.started = false
	var parcel: Entity = Entity.new()
	var identity: C_Package = C_Package.new()
	identity.package_id = visit.package_id
	identity.history_id = "1-01-NM01E"
	var state: C_PackageState = C_PackageState.new()
	parcel.component_resources = [identity, state]
	_world.add_entity(parcel)
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.MORNING
	var wallet: C_Wallet = WalletService.current()

	assert_eq(CustomerFlowService.finalize_missed_unregistered(CustomerFlowService.current(), cycle, wallet), 1)
	assert_false(visit.started)
	assert_true(visit.finished)
	assert_eq(visit.declaration, CustomerVisit.Declaration.LOST)
	assert_eq(visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
	assert_eq(visit.disposition, CustomerVisit.Disposition.LOST)
	assert_eq(visit.loss_cause, CustomerVisit.LossCause.MISSED_REGISTRATION)
	assert_eq(visit.package_history_id, identity.history_id)
	assert_true(visit.settlement_committed)
	assert_eq(wallet.balance, -300)
	assert_eq(wallet.operations[0].reason, MoneyOperation.Reason.MISSED_REGISTRATION)
	assert_null(CustomerFlowService.parcel_for(visit.package_id))
	assert_eq(CustomerFlowService.finalize_missed_unregistered(CustomerFlowService.current(), cycle, wallet), 0)
	assert_eq(wallet.operations.size(), 1)


func test_next_morning_keeps_registered_or_other_purpose_visit() -> void:
	var registered: CustomerVisit = _live_fixture()
	registered.started = false
	var parcel: Entity = _live_parcel(registered)
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = registered.package_id
	record.number = 1
	PackageRegistrationService.ledger().records.append(record)

	var other_purpose: CustomerVisit = CustomerVisit.new()
	other_purpose.visit_id = &"visit/other-purpose"
	other_purpose.package_id = "other-purpose-package"
	other_purpose.definition = DEF_Customer.new()
	other_purpose.arrival_day = 1
	other_purpose.requires_registered_package = false
	CustomerFlowService.current().visits.append(other_purpose)

	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.MORNING
	assert_eq(
		CustomerFlowService.finalize_missed_unregistered(
			CustomerFlowService.current(),
			cycle,
			WalletService.current(),
		),
		0,
	)
	assert_eq(registered.declaration, CustomerVisit.Declaration.NONE)
	assert_eq(registered.disposition, CustomerVisit.Disposition.WAREHOUSE)
	assert_true(is_instance_valid(parcel))
	assert_eq(other_purpose.declaration, CustomerVisit.Declaration.NONE)
	assert_false(other_purpose.finished)
	assert_eq(WalletService.current().balance, 0)

func test_main_scene_sessions_do_not_share_mutable_customer_records() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	var first: Node = scene.instantiate()
	var second: Node = scene.instantiate()
	var first_flow: C_CustomerFlow = null
	var second_flow: C_CustomerFlow = null
	for component: Component in (first.get_node("Entityes/DaySession") as Entity).component_resources:
		if component is C_CustomerFlow:
			first_flow = component as C_CustomerFlow
	for component: Component in (second.get_node("Entityes/DaySession") as Entity).component_resources:
		if component is C_CustomerFlow:
			second_flow = component as C_CustomerFlow
	first_flow.visits.append(_visit())
	assert_true(second_flow.visits.is_empty())
	first.free()
	second.free()
