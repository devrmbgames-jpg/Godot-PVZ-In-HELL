extends GutTest
## Proves discrete settlement, calendar complaints and deferred challenge consequence gates.

var _world: World
var _flow: C_CustomerFlow
var _cycle: C_DayCycle
var _wallet: C_Wallet
var _visit: CustomerVisit
var _outcomes: O_CustomerOutcomes

#region Fixture
## Installs real calendar and transaction owners without navigation or rendered gameplay.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_CustomerPlanning.new())
	_outcomes = O_CustomerOutcomes.new()
	_world.add_observer(_outcomes)
	_world.add_system(S_CustomerFlow.new())
	var session: Entity = Entity.new()
	session.component_resources = [C_CustomerFlow.new(), C_DayCycle.new(), C_Wallet.new()]
	_world.add_entity(session)
	_flow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	_flow.schedule = null
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.DAY
	_wallet = session.get_component(C_Wallet) as C_Wallet
	_wallet.policy = DEF_Economy.new()
	_visit = CustomerVisit.new()
	_visit.visit_id = &"outcome/fixture"
	_visit.definition = DEF_Customer.new()
	_visit.definition.max_followup_visits = 0
	_visit.definition.healthy_satisfaction = 70
	_visit.payment = 100
	_visit.accounting_value = 100
	_visit.started = true
	_visit.visit_count = 1
	_flow.visits.append(_visit)


## Frees the isolated World and transient bodies; no real save slot is touched.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _advance_challenge(delta: float) -> void:
	var owner: S_ChallengeRuntime = S_ChallengeRuntime.new()
	owner.group = "challenge_fixture"
	_world.add_system(owner)
	_world.process(delta, owner.group)
	_world.remove_system(owner)
	owner.free()


func _deliver() -> void:
	var receipt: PackageDeliveryCheck = PackageDeliveryCheck.new()
	receipt.result = PackageDeliveryCheck.Result.READY
	assert_true(CustomerOutcomeService.receive(_visit, receipt))


func _challenged_customer() -> E_Customer:
	var scene: PackedScene = load("res://content/entities/customers/customer.tscn") as PackedScene
	var customer: E_Customer = scene.instantiate() as E_Customer
	(customer as Node as RigidBody3D).freeze = true
	_world.add_entity(customer)
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.visit_id = _visit.visit_id
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var state: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	state.definition = DEF_Challenge.new()
	state.definition.key = &"fixture-challenge"
	state.definition.condition = DEF_LightChallengeCondition.new()
	state.definition.success_satisfaction_delta = 20
	state.definition.escalation_on_failure = false
	var actor: Entity = Entity.new()
	_world.add_entity(actor)
	assert_true(ChallengeService.arm(customer, actor))
	assert_true(ChallengeService.activate(customer))
	return customer
#endregion

#region Record and calendar facts
## Declaration settles a committed delivery through its fact, without waiting for a frame.
func test_record_changes_settle_once_and_replay_cannot_pay_again() -> void:
	_deliver()
	assert_eq(_wallet.balance, 0)
	assert_true(CustomerOutcomeService.declare(_visit, CustomerVisit.Declaration.TAKEN))
	assert_true(_visit.settlement_committed)
	assert_eq(_wallet.balance, 70)
	assert_eq(_wallet.operations.size(), 1)

	CustomerOutcomeService.publish_change(_visit, &"replayed_fact")
	assert_true(CustomerOutcomeService.declare(_visit, CustomerVisit.Declaration.TAKEN))
	_world.process(100.0)
	_world.process(100.0)
	assert_eq(_wallet.balance, 70)
	assert_eq(_wallet.operations.size(), 1)


## A MANUAL transaction consumer keeps the payment pending until its actual buffer commit.
func test_manual_record_consumer_does_not_claim_payment_before_flush() -> void:
	_outcomes.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_deliver()
	assert_true(CustomerOutcomeService.declare(_visit, CustomerVisit.Declaration.TAKEN))
	assert_false(_visit.settlement_committed)
	assert_eq(_wallet.balance, 0)
	_world.flush_command_buffers()
	assert_true(_visit.settlement_committed)
	assert_eq(_wallet.balance, 70)
	assert_eq(_wallet.operations.size(), 1)


## A complaint matures on a new calendar fact, rather than elapsed frame time.
func test_complaint_resolves_on_calendar_entry_and_not_repeated_frames() -> void:
	_visit.finished = true
	_visit.actual = CustomerVisit.Actual.CUSTOMER_REFUSED
	_visit.definition.voluntary_complaint_probability = 1.0
	_visit.definition.complaint_delay_days = 2
	_visit.complaint_roll = 0.0
	assert_true(CustomerOutcomeService.create_complaint(_visit, 1))
	_world.process(100.0)
	_world.process(100.0)
	assert_eq(_visit.complaint.outcome, CustomerComplaint.Outcome.PENDING)
	assert_eq(_wallet.operations.size(), 0)

	_cycle.day_index = 3
	_world.process(0.0)
	assert_eq(_visit.complaint.outcome, CustomerComplaint.Outcome.CONFIRMED)
	assert_eq(_visit.complaint.resolved_day, 3)
	assert_eq(_wallet.balance, -200)
	_world.process(100.0)
	assert_eq(_wallet.operations.size(), 1)
#endregion

#region Challenge consequence boundary
## A terminal result remains financially pending until its deferred consequences commit.
func test_challenge_result_releases_correct_payment_only_after_bridge_flush() -> void:
	var bridge: O_CustomerChallengeOutcome = O_CustomerChallengeOutcome.new()
	bridge.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.add_observer(bridge)
	var customer: E_Customer = _challenged_customer()
	var state: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	_deliver()
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.TAKEN))
	assert_false(_visit.settlement_committed)
	assert_eq(_wallet.balance, 0)

	state.condition_result = ChallengeResult.Type.SUCCESS
	_advance_challenge(0.1)
	assert_not_null(state.pending_result)
	assert_false(state.consequences_applied)
	assert_eq(_wallet.balance, 0)
	_world.flush_command_buffers()
	assert_true(state.consequences_applied)
	assert_eq(_visit.satisfaction, 90)
	assert_eq(_wallet.balance, 90)
	_world.emit_event(ChallengeResolution.EVENT, customer, state.pending_result)
	_world.flush_command_buffers()
	assert_eq(_visit.satisfaction, 90)
	assert_eq(_wallet.operations.size(), 1)


## Cancellation releases the active gate through a separate committed cleanup fact.
func test_cancelled_challenge_releases_pending_receipt_without_a_polling_frame() -> void:
	var customer: E_Customer = _challenged_customer()
	_deliver()
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.TAKEN))
	assert_eq(_wallet.balance, 0)
	ChallengeService.cancel(customer)
	assert_true(_visit.settlement_committed)
	assert_eq(_wallet.balance, 70)
	assert_eq(_visit.challenge_satisfaction_delta, 0)
	ChallengeService.cancel(customer)
	assert_eq(_wallet.operations.size(), 1)


## Final physical removal releases a finished receipt even if its challenge stayed active.
func test_removing_finished_appearance_reconciles_after_the_live_gate_is_gone() -> void:
	var customer: E_Customer = _challenged_customer()
	_deliver()
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.TAKEN))
	CustomerFlowService.finish(_visit, _cycle.day_index)
	assert_true(_visit.finished)
	assert_eq(_wallet.balance, 0)
	CustomerFlowService.remove_appearance(customer, _visit)
	assert_false(EntityAvailability.contains(customer, _world))
	assert_true(_visit.settlement_committed)
	assert_eq(_wallet.balance, 70)
	assert_eq(_wallet.operations.size(), 1)


## A superseded queued result cannot alter satisfaction after cleanup sealed that session.
func test_stale_challenge_result_is_discarded_after_cleanup() -> void:
	var bridge: O_CustomerChallengeOutcome = O_CustomerChallengeOutcome.new()
	bridge.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.add_observer(bridge)
	var customer: E_Customer = _challenged_customer()
	var state: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	_deliver()
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.TAKEN))
	state.condition_result = ChallengeResult.Type.SUCCESS
	_advance_challenge(0.1)
	ChallengeService.cancel(customer)
	_world.flush_command_buffers()
	assert_eq(_visit.challenge_satisfaction_delta, 0)
	assert_eq(_wallet.balance, 70)
	assert_eq(_wallet.operations.size(), 1)
#endregion
