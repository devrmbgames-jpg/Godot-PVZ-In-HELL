extends RefCounted
## Explicit challenge session commands and terminal facts; S_ChallengeRuntime owns time progression.
class_name ChallengeService


#region Запуск и живые связи
## Отладочный старт меняет определение только до начала одноразового испытания в дневной фазе.
static func debug_start(subject: Entity, actor: Entity, definition: DEF_Challenge) -> bool:
	if not _available(subject) or not _available(actor) or definition == null or definition.condition == null:
		return false

	var cycle: C_DayCycle = DayPhaseQueries.current()
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	if cycle == null or cycle.phase != C_DayCycle.Phase.DAY or (state != null and (state.consumed or state.phase != C_Challenge.Phase.INACTIVE)):
		return false
	if state == null:
		state = C_Challenge.new()
		subject.add_component(state)
	state.definition = definition
	return arm(subject, actor) and activate(subject)


## Однократно фиксирует запуск в дневной фазе и связь с участником.
static func arm(subject: Entity, actor: Entity) -> bool:
	if not _available(subject) or not _available(actor):
		return false

	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if (
		state == null or state.definition == null or state.definition.condition == null
		or state.consumed or state.phase != C_Challenge.Phase.INACTIVE
		or cycle == null or cycle.phase != C_DayCycle.Phase.DAY
	):
		return false

	state.consumed = true
	state.phase = C_Challenge.Phase.ARMED
	state.started_day = cycle.day_index
	state.started_phase = cycle.phase
	subject.add_relationship(Relationship.new(R_ChallengeActor.new(), actor))
	return true


## Переводит действующий ARMED-сеанс в ACTIVE со сбросом часов.
static func activate(subject: Entity) -> bool:
	if not _available(subject):
		return false

	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	if state == null or state.phase != C_Challenge.Phase.ARMED or not _valid_session(subject, state):
		return false

	state.phase = C_Challenge.Phase.ACTIVE
	state.elapsed = 0.0

	var activated: ChallengeActivated = ChallengeActivated.new()
	activated.definition = state.definition
	ECS.world.emit_event(ChallengeActivated.EVENT, subject, activated)
	return true


## Запускает только условие ON_ARRIVAL через обычные arm/activate.
static func begin_on_arrival(subject: Entity, actor: Entity) -> bool:
	if not _available(subject):
		return false

	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	return (
		state != null and state.definition != null
		and state.definition.trigger == DEF_Challenge.Trigger.ON_ARRIVAL
		and arm(subject, actor) and activate(subject)
	)


## Запоминает уход для активного условия с завершением до ухода.
static func request_departure(subject: Entity) -> void:
	if not is_instance_valid(subject):
		return

	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	if (
		state != null and state.definition != null and state.phase == C_Challenge.Phase.ACTIVE
		and state.definition.completion in [DEF_Challenge.Completion.UNTIL_DEPARTURE, DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE]
	):
		state.departure_requested = true


## Возвращает доступного живого участника из R_ChallengeActor.
static func actor_for(subject: Entity) -> Entity:
	if not is_instance_valid(subject):
		return null

	for relation: Relationship in subject.relationships:
		if relation.relation is R_ChallengeActor:
			if EntityAvailability.contains(relation.target, ECS.world):
				var actor: Entity = relation.target as Entity
				return actor if not actor.has_component(C_Death) else null
			return null
	return null


#endregion

#region Отмена и завершение
## Closes a terminal display after its owning System has exhausted the timer.
static func close(subject: Entity) -> void:
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	assert(state != null and state.phase in [C_Challenge.Phase.SUCCESS, C_Challenge.Phase.FAILURE])
	assert(state.result_remaining <= 0.0)
	_cleanup(subject, state)


## Идемпотентно отменяет незавершённый итог и очищает эффекты/участие.
static func cancel(subject: Entity) -> void:
	if not is_instance_valid(subject):
		return

	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	if state == null or state.phase in [C_Challenge.Phase.INACTIVE, C_Challenge.Phase.CLEANUP]:
		return
	if state.result == ChallengeResult.Type.NONE:
		state.result = ChallengeResult.Type.CANCELLED
	_cleanup(subject, state)


## Отменяет испытание недоступного носителя и связанные сеансы с потерянным участником/эффектом.
static func entity_unavailable(entity: Entity) -> void:
	if is_instance_valid(entity):
		cancel(entity)
	if not is_instance_valid(ECS.world):
		return

	for subject: Entity in ECS.world.query.with_all([C_Challenge]).execute():
		for relation: Relationship in subject.relationships:
			if relation.relation is R_ChallengeActor and relation.target == entity:
				cancel(subject)
				break
			if relation.relation is R_ChallengeEffect and relation.target == entity:
				var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
				if state.phase in [C_Challenge.Phase.ARMED, C_Challenge.Phase.ACTIVE]:
					cancel(subject)
				break


## Читает сохранённый общий итог либо NONE.
static func result_for(subject: Entity) -> ChallengeResult.Type:
	if not is_instance_valid(subject):
		return ChallengeResult.Type.NONE

	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	return state.result if state != null else ChallengeResult.Type.NONE


## Проверяет живых участников и совпадение дня/фазы запуска.
static func session_valid(subject: Entity) -> bool:
	if not _available(subject):
		return false

	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	return state != null and _valid_session(subject, state)


#endregion

#region Проверки и однократный итог
static func _valid_session(subject: Entity, state: C_Challenge) -> bool:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	return (
		_available(subject) and actor_for(subject) != null and cycle != null
		and cycle.day_index == state.started_day and cycle.phase == state.started_phase
	)


static func _available(entity: Entity) -> bool:
	return EntityAvailability.contains(entity, ECS.world) and not entity.has_component(C_Death)


## Commits one terminal result before publishing its typed fact; the session must be ACTIVE.
static func resolve(subject: Entity, result: ChallengeResult.Type) -> void:
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	assert(state != null and state.phase == C_Challenge.Phase.ACTIVE)
	assert(result in [ChallengeResult.Type.SUCCESS, ChallengeResult.Type.FAILURE])

	state.result = result
	state.phase = C_Challenge.Phase.SUCCESS if result == ChallengeResult.Type.SUCCESS else C_Challenge.Phase.FAILURE
	state.result_remaining = state.definition.result_display_seconds
	var event: ChallengeResolution = ChallengeResolution.new()
	event.challenge_key = state.definition.key
	event.result = result
	event.satisfaction_delta = state.definition.success_satisfaction_delta if result == ChallengeResult.Type.SUCCESS else state.definition.failure_satisfaction_delta
	event.request_escalation = result == ChallengeResult.Type.FAILURE and state.definition.escalation_on_failure
	state.pending_result = event
	ECS.world.emit_event(ChallengeResolution.EVENT, subject, event)


static func _cleanup(subject: Entity, state: C_Challenge) -> void:
	var light_rule: DEF_LightChallengeCondition = state.definition.condition as DEF_LightChallengeCondition if state.definition != null else null
	if light_rule != null and light_rule.wait_outside_until_dark:
		LightCircuitService.stop_flicker(light_rule.circuit_id, StringName(subject.id))
	state.phase = C_Challenge.Phase.CLEANUP
	state.elapsed = 0.0
	state.result_remaining = 0.0
	state.condition_result = ChallengeResult.Type.NONE
	state.violation_elapsed = 0.0
	state.departure_requested = false
	state.pending_result = null
	var floor: C_FloorChallenge = subject.get_component(C_FloorChallenge) as C_FloorChallenge
	if floor != null:
		floor.touching_danger = false

	ChallengeEffectLifecycle.retire(subject)
	for relation: Relationship in subject.relationships.duplicate():
		if relation.relation is R_ChallengeActor:
			subject.remove_relationship(relation)

	# Publish cleanup after its live participation bindings have been released.
	var closed: ChallengeSessionClosed = ChallengeSessionClosed.new()
	closed.challenge_key = state.definition.key if state.definition != null else &""
	closed.result = state.result
	ECS.world.emit_event(ChallengeSessionClosed.EVENT, subject, closed)

#endregion
