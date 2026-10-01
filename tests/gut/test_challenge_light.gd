extends GutTest

const FRAME_DELTA: float = 0.1
const TIMEOUT: float = 2.0
const VISIT_ID: StringName = &"challenge-test"

var _world: World = null
var _actor: Entity = null
var _subject: Entity = null
var _circuit: Entity = null
var _state: C_Challenge = null
var _cycle: C_DayCycle = null
var _visit: CustomerVisit = null
var _escalations: int = 0


func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_ChallengeLight.new())
	_world.add_system(S_ChallengeRuntime.new())
	var receiver: S_CustomerChallengeOutcome = S_CustomerChallengeOutcome.new()
	receiver.escalation_requested.connect(_on_escalation)
	_world.add_system(receiver)
	_world.add_observer(O_ChallengeLifecycle.new())
	var session: Entity = _entity([C_DayCycle.new(), C_CustomerFlow.new(), C_Wallet.new()])
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.DAY
	_actor = _entity([])
	var customer_body: RigidBody3D = RigidBody3D.new()
	customer_body.set_script(load("res://content/entities/customers/e_customer.gd"))
	_subject = customer_body as Node as E_Customer
	_subject.component_resources = [C_Challenge.new(), C_CustomerAgent.new(), C_NpcIntent.new(), C_Controller.new()]
	_world.add_entity(_subject)
	(_subject.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id = VISIT_ID
	_state = _subject.get_component(C_Challenge) as C_Challenge
	_state.definition = DEF_Challenge.new()
	_state.definition.key = &"light-off"
	_state.definition.condition = DEF_LightChallengeCondition.new()
	_state.definition.timeout_seconds = TIMEOUT
	_visit = CustomerVisit.new()
	_visit.visit_id = VISIT_ID
	_visit.visit_count = 1
	_visit.started = true
	_visit.definition = DEF_Customer.new()
	(session.get_component(C_CustomerFlow) as C_CustomerFlow).visits.append(_visit)
	_circuit = _entity([C_LightCircuit.new()])
	_escalations = 0


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_actor = null
	_subject = null
	_circuit = null
	_state = null
	_cycle = null
	_visit = null


func _entity(components: Array[Component]) -> Entity:
	var entity: Entity = Entity.new()
	entity.component_resources = components
	_world.add_entity(entity)
	return entity


func _start() -> void:
	assert_true(ChallengeService.arm(_subject, _actor))
	assert_true(ChallengeService.activate(_subject))


func _on_escalation(subject: Entity, actor: Entity, event: ChallengeResolution) -> void:
	assert_eq(subject, _subject)
	assert_eq(actor, _actor)
	assert_eq(event.result, ChallengeResult.Type.FAILURE)
	_escalations += 1


func test_armed_waits_for_dialogue_close_before_countdown() -> void:
	assert_true(ChallengeService.arm(_subject, _actor))
	_world.process(TIMEOUT * 2.0)
	assert_eq(_state.phase, C_Challenge.Phase.ARMED)
	assert_eq(_state.elapsed, 0.0)
	assert_eq(ChallengeService.actor_for(_subject), _actor)
	assert_true(ChallengeService.activate(_subject))
	_world.process(FRAME_DELTA)
	assert_almost_eq(_state.elapsed, FRAME_DELTA, 0.0001)


func test_physical_circuit_command_succeeds_and_cleans_binding() -> void:
	_start()
	assert_true(LightCircuitService.toggle(_circuit))
	_world.process(FRAME_DELTA)
	assert_eq(_state.phase, C_Challenge.Phase.SUCCESS)
	assert_eq(_state.result, ChallengeResult.Type.SUCCESS)
	assert_eq(_visit.challenge_satisfaction_delta, 10)
	assert_eq(_visit.challenge_result, &"success")
	assert_eq(_escalations, 0)
	_world.process(_state.definition.result_display_seconds)
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_state.elapsed, 0.0)
	assert_null(ChallengeService.actor_for(_subject))
	assert_false(ChallengeService.arm(_subject, _actor))


func test_light_on_uses_the_same_condition_code() -> void:
	(_state.definition.condition as DEF_LightChallengeCondition).required_enabled = true
	(_circuit.get_component(C_LightCircuit) as C_LightCircuit).enabled = false
	_start()
	_world.process(FRAME_DELTA)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	assert_true(LightCircuitService.toggle(_circuit))
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.SUCCESS)


func test_timeout_applies_failure_and_escalation_once() -> void:
	_start()
	_world.process(TIMEOUT)
	assert_eq(_state.phase, C_Challenge.Phase.FAILURE)
	assert_eq(_visit.challenge_satisfaction_delta, -30)
	assert_eq(_visit.satisfaction, 70)
	assert_eq(_escalations, 1)
	assert_not_null(_state.escalation_request)
	_world.process(TIMEOUT)
	assert_eq(_visit.challenge_satisfaction_delta, -30)
	assert_eq(_escalations, 1)


func test_duplicate_trigger_does_not_restart_or_rebind() -> void:
	_start()
	_world.process(FRAME_DELTA)
	assert_false(ChallengeService.arm(_subject, _actor))
	assert_false(ChallengeService.activate(_subject))
	assert_almost_eq(_state.elapsed, FRAME_DELTA, 0.0001)
	assert_eq(_subject.get_relationships(Relationship.new(R_ChallengeActor.new())).size(), 1)


func test_missing_circuit_cannot_falsely_satisfy_light_off() -> void:
	_world.remove_entity(_circuit)
	_start()
	_world.process(FRAME_DELTA)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	_world.process(TIMEOUT)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)


func test_actor_removal_cleans_without_satisfaction_penalty() -> void:
	_start()
	_world.remove_entity(_actor)
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_visit.challenge_satisfaction_delta, 0)
	assert_null(ChallengeService.actor_for(_subject))


func test_subject_removal_cleans_retained_state() -> void:
	_start()
	_world.remove_entity(_subject)
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_state.elapsed, 0.0)


func test_player_death_cancels_active_challenge() -> void:
	_start()
	_actor.add_component(C_Death.new())
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_visit.challenge_satisfaction_delta, 0)
	assert_null(ChallengeService.actor_for(_subject))


func test_phase_and_day_change_cancel_armed_or_active_challenge() -> void:
	assert_true(ChallengeService.arm(_subject, _actor))
	_cycle.phase = C_DayCycle.Phase.EVENING
	_world.process(FRAME_DELTA)
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_visit.challenge_satisfaction_delta, 0)


func test_next_day_cancels_active_challenge() -> void:
	_start()
	_cycle.day_index += 1
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_null(_state.pending_result)


func test_persistent_result_prevents_duplicate_consequence_and_escalation() -> void:
	_start()
	_world.process(TIMEOUT)
	_state.consequences_applied = false
	_world.process(FRAME_DELTA)
	assert_eq(_visit.challenge_satisfaction_delta, -30)
	assert_eq(_escalations, 1)


func _visit_challenge() -> void:
	_state.definition.trigger = DEF_Challenge.Trigger.ON_ARRIVAL
	_state.definition.completion = DEF_Challenge.Completion.UNTIL_DEPARTURE
	_state.definition.preparation_seconds = 1.0
	_state.definition.violation_grace_seconds = 0.5
	_state.definition.timeout_seconds = 0.0


func test_arrival_starts_and_satisfied_condition_waits_until_departure() -> void:
	_visit_challenge()
	assert_true(LightCircuitService.set_enabled(_circuit, false))
	assert_true(ChallengeService.begin_on_arrival(_subject, _actor))
	_world.process(TIMEOUT * 2.0)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	assert_eq(_state.result, ChallengeResult.Type.NONE)
	assert_eq(_visit.challenge_satisfaction_delta, 0)
	ChallengeService.request_departure(_subject)
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.SUCCESS)
	assert_eq(_visit.challenge_satisfaction_delta, 10)
	_world.process(FRAME_DELTA)
	assert_eq(_visit.challenge_satisfaction_delta, 10)


func test_visit_preparation_allows_switching_before_condition_is_enforced() -> void:
	_visit_challenge()
	assert_true(ChallengeService.begin_on_arrival(_subject, _actor))
	_world.process(0.75)
	assert_false(_state.condition_violated)
	assert_true(LightCircuitService.toggle(_circuit))
	_world.process(TIMEOUT)
	assert_false(_state.condition_violated)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)


func test_visit_violation_is_recorded_but_result_is_applied_only_at_departure() -> void:
	_visit_challenge()
	assert_true(ChallengeService.begin_on_arrival(_subject, _actor))
	_world.process(2.0)
	assert_true(_state.condition_violated)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	assert_eq(_visit.challenge_satisfaction_delta, 0)
	assert_eq(_escalations, 0)
	assert_true(LightCircuitService.toggle(_circuit))
	_world.process(FRAME_DELTA)
	ChallengeService.request_departure(_subject)
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)
	assert_eq(_visit.challenge_satisfaction_delta, -30)
	assert_eq(_escalations, 1)


func test_debug_ui_reports_task_condition_timer_and_visit_window() -> void:
	_state.definition.rule_text = "Выключить свет"
	_start()
	_world.process(FRAME_DELTA)
	var text: String = ChallengePresentation.debug_text_for(_actor)
	assert_string_contains(text, "Задача: Выключить свет")
	assert_string_contains(text, "Условие warehouse: нужно ВЫКЛ")
	assert_string_contains(text, "ACTIVE")
	assert_string_contains(text, "Таймер 0.1 / 2.0 с")
	_state.definition.completion = DEF_Challenge.Completion.UNTIL_DEPARTURE
	assert_string_contains(ChallengePresentation.debug_text_for(_actor), "До ухода")


func _deliver_and_declare() -> C_Wallet:
	_visit.payment = 100
	var check_result: PackageDeliveryCheck = PackageDeliveryCheck.new()
	check_result.result = PackageDeliveryCheck.Result.READY
	assert_true(CustomerOutcomeService.receive(_visit, check_result))
	assert_true(CustomerFlowService.declare(VISIT_ID, CustomerVisit.Declaration.TAKEN))
	return WalletService.current()


func test_delivery_payment_waits_for_timed_challenge_result() -> void:
	_start()
	var wallet: C_Wallet = _deliver_and_declare()
	assert_eq(wallet.balance, 0)
	assert_false(_visit.settlement_committed)
	_world.process(TIMEOUT)
	CustomerFlowService.tick(CustomerFlowService.current(), _cycle, 0.0)
	assert_eq(_visit.satisfaction, 70)
	assert_eq(wallet.balance, 70)
	CustomerFlowService.tick(CustomerFlowService.current(), _cycle, 0.0)
	assert_eq(wallet.operations.size(), 1)


func test_departure_result_precedes_removal_and_payment() -> void:
	_visit_challenge()
	assert_true(ChallengeService.begin_on_arrival(_subject, _actor))
	var wallet: C_Wallet = _deliver_and_declare()
	var agent: C_CustomerAgent = _subject.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.RECEIVING
	CustomerFlowService.tick(CustomerFlowService.current(), _cycle, _visit.definition.receiving_seconds)
	_world.process(TIMEOUT)
	assert_eq(agent.phase, C_CustomerAgent.Phase.LEAVING)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	assert_eq(wallet.balance, 0)
	CustomerFlowService.tick(CustomerFlowService.current(), _cycle, _visit.definition.leaving_seconds)
	assert_false(_visit.finished)
	assert_true(EntityAvailability.contains(_subject, _world))
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)
	assert_eq(_visit.satisfaction, 70)
	CustomerFlowService.tick(CustomerFlowService.current(), _cycle, 0.0)
	assert_true(_visit.finished)
	assert_eq(wallet.balance, 70)
	assert_eq(wallet.operations.size(), 1)
