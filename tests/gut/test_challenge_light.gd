extends GutTest
## Проверяет световые условия, подтверждение, таймауты и применение результата испытания к визиту.

class TerminalRetirer extends Observer:
	## Counts actual terminal facts after their state is committed.
	var fact_count: int = 0
	## Records whether phase, payload and result were visible before publication.
	var saw_committed_state: bool = false

	#region Committed terminal consumer
	## Selects actual typed challenge results.
	func query() -> QueryBuilder:
		return q.with_all([C_Challenge]).on_event(ChallengeResolution.EVENT)

	## Cancels and retires the subject synchronously to exercise the producer's lifetime boundary.
	func each(_event: Variant, subject: Entity, payload: Variant = null) -> void:
		var resolution: ChallengeResolution = payload as ChallengeResolution
		var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
		fact_count += 1
		saw_committed_state = state.pending_result == resolution and state.result == resolution.result \
				and state.phase == C_Challenge.Phase.FAILURE
		ChallengeService.cancel(subject)
		_world.remove_entity(subject)
	#endregion


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
var _resolved_calls: int = 0
var _runtime: S_ChallengeRuntime


#region Окружение световой цепи
## Создаёт световую цепь, участника и сервисный визит с коротким таймаутом.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_ChallengeLight.new())
	_runtime = S_ChallengeRuntime.new()
	_runtime.resolved.connect(_on_resolved)
	_world.add_system(_runtime)
	var receiver: O_CustomerChallengeOutcome = O_CustomerChallengeOutcome.new()
	receiver.escalation_requested.connect(_on_escalation)
	_world.add_observer(receiver)
	_world.add_observer(O_ChallengeLifecycle.new())

	var session: Entity = _entity([C_DayCycle.new(), C_CustomerFlow.new(), C_Wallet.new()])
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.DAY
	_actor = _entity([])
	var customer_body: RigidBody3D = RigidBody3D.new()
	customer_body.set_script(load("res://content/domains/customers/entities/e_customer.gd"))
	_subject = customer_body as Node as E_NpcCharacter
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
	_resolved_calls = 0


## Удаляет World и очищает ссылки участников и состояния испытания.
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


func _on_resolved(_subject_value: Entity, _actor_value: Entity, _event_value: ChallengeResolution) -> void:
	_resolved_calls += 1



func _on_escalation(subject: Entity, actor: Entity, event: ChallengeResolution) -> void:
	assert_eq(subject, _subject)
	assert_eq(actor, _actor)
	assert_eq(event.result, ChallengeResult.Type.FAILURE)
	_escalations += 1


#endregion

#region Начало и вход клиента
## Подготовленное требование ждёт закрытия подтверждённого диалога перед отсчётом.
func test_armed_waits_for_dialogue_close_before_countdown() -> void:
	assert_true(ChallengeService.arm(_subject, _actor))
	_world.process(TIMEOUT * 2.0)
	assert_eq(_state.phase, C_Challenge.Phase.ARMED)
	assert_eq(_state.elapsed, 0.0)
	assert_eq(ChallengeService.actor_for(_subject), _actor)
	assert_true(ChallengeService.activate(_subject))
	_world.process(FRAME_DELTA)
	assert_almost_eq(_state.elapsed, FRAME_DELTA, 0.0001)


func _advance_arrival() -> void:
	# Exercise only the actual approach owner, preserving the fixture's challenge clocks.
	var agent: C_CustomerAgent = _subject.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.scheduled_phase = int(agent.phase)
	var owner: S_CustomerApproach = S_CustomerApproach.new()
	owner.group = "arrival_fixture"
	_world.add_system(owner)
	_world.process(0.0, owner.group)
	_world.remove_system(owner)
	owner.free()


func _arrival_customer() -> E_NpcCharacter:
	_state.definition = (load("res://content/definitions/gameplay/challenges/def_challenge_light_entrance.tres") as DEF_Challenge).duplicate(true) as DEF_Challenge
	_state.definition.timeout_seconds = TIMEOUT
	_visit.definition.challenge = _state.definition
	assert_true(ChallengeService.begin_on_arrival(_subject, _actor))
	var customer: E_NpcCharacter = _subject as E_NpcCharacter
	CustomerArrivalService.begin(customer, _state)
	return customer


## Светобоязненный клиент ждёт у входа, затем получает намерение подхода после выключения.
func test_dark_room_customer_waits_then_approaches_after_switch_off() -> void:
	var customer: E_NpcCharacter = _arrival_customer()
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(agent.phase, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS)
	_advance_arrival()
	assert_eq(agent.phase, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS)
	_world.process(FRAME_DELTA)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)

	var scene: PackedScene = load("res://content/domains/customers/entities/delivery_counter.tscn") as PackedScene
	var station: E_DeliveryCounter = scene.instantiate() as E_DeliveryCounter
	_world.add_entity(station)
	assert_true(LightCircuitService.set_enabled(_circuit, false))
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.SUCCESS)
	_advance_arrival()
	assert_eq(agent.phase, C_CustomerAgent.Phase.APPROACHING)

	var intent: C_NpcIntent = customer.get_component(C_NpcIntent) as C_NpcIntent
	assert_eq(intent.move_position, station.waiting_position())
	assert_eq(_escalations, 0)


## Таймаут гасит свет и направляет одну эскалацию в существующую боевую роль.
func test_dark_room_timeout_turns_lights_off_and_reuses_combat_escalation_once() -> void:
	var customer: E_NpcCharacter = _arrival_customer()
	_actor.add_components([C_PlayerInputController.new(), C_Health.new()])
	customer.add_component(C_NpcCombat.new())
	_world.process(TIMEOUT)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)
	assert_false(LightCircuitService.is_enabled(&"warehouse"))
	assert_eq(_escalations, 1)
	CombatFixture.customer(customer)
	assert_true(_visit.aggressive)
	assert_eq((customer.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.AGGRESSIVE)
	assert_same(CombatService.target_for(customer), _actor)
	_world.process(FRAME_DELTA)
	CombatFixture.customer(customer)
	assert_eq(_escalations, 1)


## Уже тёмный вход не задерживает клиента и не мерцает; смена фазы не оставляет его у входа.
func test_already_dark_arrival_does_not_gate_or_flicker_and_phase_cancel_departs() -> void:
	assert_true(LightCircuitService.set_enabled(_circuit, false))
	var customer: E_NpcCharacter = _arrival_customer()
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(agent.phase, C_CustomerAgent.Phase.APPROACHING)
	assert_false(LightCircuitService.flicker(&"warehouse", 2.0, 0.1))
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.SUCCESS)
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_DARKNESS
	_cycle.phase = C_DayCycle.Phase.EVENING
	_advance_arrival()
	assert_eq(agent.phase, C_CustomerAgent.Phase.LEAVING, "Phase change must not strand the entrance")


func _flickering_view() -> CircuitLightView:
	_world.add_observer(O_LightFlicker.new())
	var light: OmniLight3D = OmniLight3D.new()
	_world.add_child(light)
	light.add_to_group(&"warehouse_lights")
	var view: CircuitLightView = CircuitLightView.new()
	view.name = "CircuitLightView"
	light.add_child(view)
	view.set_process(false)
	return view


#endregion

#region Мерцание и команды
## Смена фазы снимает временное мерцание, сохраняя enabled световой цепи.
func test_phase_change_cancels_arrival_flicker_without_switching_room_off() -> void:
	var view: CircuitLightView = _flickering_view()
	_arrival_customer()
	view._process(0.16)
	assert_false((view.get_parent() as Light3D).visible)
	_cycle.phase = C_DayCycle.Phase.EVENING
	_world.process(FRAME_DELTA)
	view._process(0.0)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_true(LightCircuitService.is_enabled(&"warehouse"))
	assert_true((view.get_parent() as Light3D).visible, "No request may survive its challenge into the next phase")
	assert_eq(_escalations, 0)


## Удаление источника снимает его мерцание; устаревший ID не отменяет новый запрос.
func test_subject_removal_cancels_owned_flicker_and_stale_stop_cannot_clear_new_request() -> void:
	var view: CircuitLightView = _flickering_view()
	_arrival_customer()
	view._process(0.16)
	assert_false((view.get_parent() as Light3D).visible)
	_world.remove_entity(_subject)
	view._process(0.0)
	assert_true((view.get_parent() as Light3D).visible)
	assert_true(LightCircuitService.flicker(&"warehouse", 2.0, 0.15, &"new-request"))
	view._process(0.16)
	assert_false((view.get_parent() as Light3D).visible)
	LightCircuitService.stop_flicker(&"warehouse", &"old-request")
	view._process(0.0)
	assert_false((view.get_parent() as Light3D).visible)
	LightCircuitService.stop_flicker(&"warehouse", &"new-request")
	view._process(0.0)
	assert_true((view.get_parent() as Light3D).visible)


## Команда реальной цепи даёт успех и освобождает связь участника после показа результата.
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


## Требование включить свет использует тот же код условия с обратной настройкой.
func test_light_on_uses_the_same_condition_code() -> void:
	(_state.definition.condition as DEF_LightChallengeCondition).required_enabled = true
	(_circuit.get_component(C_LightCircuit) as C_LightCircuit).enabled = false
	_start()
	_world.process(FRAME_DELTA)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	assert_true(LightCircuitService.toggle(_circuit))
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.SUCCESS)


#endregion

#region Однократный исход и отмена
## Таймаут однократно меняет удовлетворённость и запрашивает эскалацию.
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


## Повторные arm/activate не сбрасывают время и не дублируют связь.
func test_duplicate_trigger_does_not_restart_or_rebind() -> void:
	_start()
	_world.process(FRAME_DELTA)
	assert_false(ChallengeService.arm(_subject, _actor))
	assert_false(ChallengeService.activate(_subject))
	assert_almost_eq(_state.elapsed, FRAME_DELTA, 0.0001)
	assert_eq(_subject.get_relationships(Relationship.new(R_ChallengeActor.new())).size(), 1)


## Отсутствующая цепь не считается успешно выключенной.
func test_missing_circuit_cannot_falsely_satisfy_light_off() -> void:
	_world.remove_entity(_circuit)
	_start()
	_world.process(FRAME_DELTA)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	_world.process(TIMEOUT)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)


## Удаление участника отменяет испытание без штрафа удовлетворённости.
func test_actor_removal_cleans_without_satisfaction_penalty() -> void:
	_start()
	_world.remove_entity(_actor)
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_visit.challenge_satisfaction_delta, 0)
	assert_null(ChallengeService.actor_for(_subject))


## Удаление источника очищает сохранённое состояние и часы.
func test_subject_removal_cleans_retained_state() -> void:
	_start()
	_world.remove_entity(_subject)
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_state.elapsed, 0.0)


## Смерть игрока отменяет действующее испытание и освобождает связь.
func test_player_death_cancels_active_challenge() -> void:
	_start()
	_actor.add_component(C_Death.new())
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_visit.challenge_satisfaction_delta, 0)
	assert_null(ChallengeService.actor_for(_subject))


## Смена фазы отменяет ещё подготовленное требование без последствий.
func test_phase_and_day_change_cancel_armed_or_active_challenge() -> void:
	assert_true(ChallengeService.arm(_subject, _actor))
	_cycle.phase = C_DayCycle.Phase.EVENING
	_world.process(FRAME_DELTA)
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_visit.challenge_satisfaction_delta, 0)


## Следующий день снимает активный и ожидающий результат.
func test_next_day_cancels_active_challenge() -> void:
	_start()
	_cycle.day_index += 1
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_null(_state.pending_result)


## Постоянная запись исхода предотвращает повторные последствия и эскалацию.
func test_persistent_result_prevents_duplicate_consequence_and_escalation() -> void:
	_start()
	_world.process(TIMEOUT)
	_state.consequences_applied = false
	_world.process(FRAME_DELTA)
	assert_eq(_visit.challenge_satisfaction_delta, -30)
	assert_eq(_escalations, 1)


#endregion

#region Условие до ухода
func _visit_challenge() -> void:
	_state.definition.trigger = DEF_Challenge.Trigger.ON_ARRIVAL
	_state.definition.completion = DEF_Challenge.Completion.UNTIL_DEPARTURE
	_state.definition.preparation_seconds = 1.0
	_state.definition.violation_grace_seconds = 0.5
	_state.definition.timeout_seconds = 0.0


## Режим UNTIL_DEPARTURE начинается при приходе и ждёт ухода даже при выполненном условии.
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


## Подготовка даёт время переключить свет до учёта нарушения.
func test_visit_preparation_allows_switching_before_condition_is_enforced() -> void:
	_visit_challenge()
	assert_true(ChallengeService.begin_on_arrival(_subject, _actor))
	_world.process(0.75)
	assert_false(_state.condition_violated)
	assert_true(LightCircuitService.toggle(_circuit))
	_world.process(TIMEOUT)
	assert_false(_state.condition_violated)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)


## Нарушение запоминается во время визита; последствия фиксируются при уходе.
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


## Отладочный UI сообщает правило, состояние цепи, часы и окно до ухода.
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


#endregion

#region Выдача и окончательный расчёт
func _deliver_and_declare() -> C_Wallet:
	_visit.payment = 100
	var check_result: PackageDeliveryCheck = PackageDeliveryCheck.new()
	check_result.result = PackageDeliveryCheck.Result.READY
	assert_true(CustomerOutcomeService.receive(_visit, check_result))
	assert_true(CustomerFlowService.declare(VISIT_ID, CustomerVisit.Declaration.TAKEN))
	return WalletService.current()


## Оплата реальной выдачи ждёт итоговой удовлетворённости и не повторяется.
func test_delivery_payment_waits_for_timed_challenge_result() -> void:
	_start()
	var wallet: C_Wallet = _deliver_and_declare()
	assert_eq(wallet.balance, 0)
	assert_false(_visit.settlement_committed)
	_world.process(TIMEOUT)
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, 0.0)
	assert_eq(_visit.satisfaction, 70)
	assert_eq(wallet.balance, 70)
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, 0.0)
	assert_eq(wallet.operations.size(), 1)


## Итог испытания ухода применяется до удаления клиента и окончательного расчёта.
func test_departure_result_precedes_removal_and_payment() -> void:
	_visit_challenge()
	assert_true(ChallengeService.begin_on_arrival(_subject, _actor))
	var wallet: C_Wallet = _deliver_and_declare()
	var agent: C_CustomerAgent = _subject.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.RECEIVING
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, _visit.definition.receiving_seconds)
	_world.process(TIMEOUT)
	assert_eq(agent.phase, C_CustomerAgent.Phase.LEAVING)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	assert_eq(wallet.balance, 0)
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, _visit.definition.leaving_seconds)
	assert_false(_visit.finished)
	assert_true(EntityAvailability.contains(_subject, _world))
	_world.process(FRAME_DELTA)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)
	assert_eq(_visit.satisfaction, 70)
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, 0.0)
	assert_true(_visit.finished)
	assert_eq(wallet.balance, 70)
	assert_eq(wallet.operations.size(), 1)

#endregion

#region Deferred lifecycle and reentrant terminal facts
## A queued ARMED step cannot start consuming an ACTIVE session's clock.
func test_manual_armed_step_rejects_activation_before_flush() -> void:
	assert_true(ChallengeService.arm(_subject, _actor))
	_runtime.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.process(TIMEOUT)
	assert_true(ChallengeService.activate(_subject))
	_world.flush_command_buffers()
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	assert_eq(_state.elapsed, 0.0)
	assert_eq(_state.result, ChallengeResult.Type.NONE)
	_runtime.command_buffer_flush_mode = System.FlushMode.PER_SYSTEM
	_world.process(FRAME_DELTA)
	assert_almost_eq(_state.elapsed, FRAME_DELTA, 0.0001)


## Replacing a cancelled component cannot inherit time from its queued predecessor.
func test_manual_runtime_rejects_replaced_component() -> void:
	_start()
	_runtime.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.process(TIMEOUT)
	var definition: DEF_Challenge = _state.definition
	ChallengeService.cancel(_subject)
	_subject.remove_component(C_Challenge)
	_state = C_Challenge.new()
	_state.definition = definition
	_subject.add_component(_state)
	_start()
	_world.flush_command_buffers()
	assert_eq(_state.elapsed, 0.0)
	assert_eq(_state.phase, C_Challenge.Phase.ACTIVE)
	assert_eq(_visit.challenge_satisfaction_delta, 0)
	assert_eq(_resolved_calls, 0)


## A queued step rechecks its calendar before committing any timeout penalty.
func test_manual_calendar_change_cancels_before_timeout_commit() -> void:
	_start()
	_runtime.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.process(TIMEOUT)
	_cycle.day_index += 1
	_world.flush_command_buffers()
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_state.result, ChallengeResult.Type.CANCELLED)
	assert_eq(_visit.challenge_satisfaction_delta, 0)
	assert_eq(_resolved_calls, 0)


## Invalid deltas consume neither active nor display time; display begins on the next step.
func test_invalid_delta_and_result_display_use_separate_steps() -> void:
	_start()
	_world.process(NAN)
	_world.process(INF)
	_world.process(-FRAME_DELTA)
	assert_eq(_state.elapsed, 0.0)
	_world.process(TIMEOUT)
	assert_eq(_state.phase, C_Challenge.Phase.FAILURE)
	assert_eq(_state.result_remaining, _state.definition.result_display_seconds)
	assert_eq(_resolved_calls, 1)
	_world.process(INF)
	assert_eq(_state.result_remaining, _state.definition.result_display_seconds)
	_world.process(_state.definition.result_display_seconds)
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)
	assert_null(ChallengeService.actor_for(_subject))
	assert_eq(_resolved_calls, 1)


## A committed fact consumer may close/remove the body before the scheduled stage returns.
func test_reentrant_terminal_consumer_retires_subject_without_stale_signal() -> void:
	var consumer: TerminalRetirer = TerminalRetirer.new()
	_world.add_observer(consumer)
	_start()
	_world.process(TIMEOUT)
	assert_eq(consumer.fact_count, 1)
	assert_true(consumer.saw_committed_state)
	assert_eq(_state.phase, C_Challenge.Phase.CLEANUP)
	assert_eq(_state.result, ChallengeResult.Type.FAILURE)
	assert_null(_state.pending_result)
	assert_false(EntityAvailability.contains(_subject, _world))
	assert_eq(_resolved_calls, 0)
	assert_eq(_visit.challenge_satisfaction_delta, -30)
#endregion
