extends RefCounted
## Generic bounded lifecycle. Conditions and customer consequences are separate producers/consumers.
class_name ChallengeService


## Debug configuration is allowed only before the one-shot challenge has begun.
static func debug_start(subject: Entity, actor: Entity, definition: DEF_Challenge) -> bool:
	if not _available(subject) or not _available(actor) or definition == null or definition.condition == null:
		return false
	var cycle: C_DayCycle = DayPhaseService.current()
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	if cycle == null or cycle.phase != C_DayCycle.Phase.DAY or (state != null and (state.consumed or state.phase != C_Challenge.Phase.INACTIVE)):
		return false
	if state == null:
		state = C_Challenge.new()
		subject.add_component(state)
	state.definition = definition
	return arm(subject, actor) and activate(subject)


static func arm(subject: Entity, actor: Entity) -> bool:
	if not _available(subject) or not _available(actor):
		return false
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	var cycle: C_DayCycle = DayPhaseService.current()
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


static func activate(subject: Entity) -> bool:
	if not _available(subject):
		return false
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	if state == null or state.phase != C_Challenge.Phase.ARMED or not _valid_session(subject, state):
		return false
	state.phase = C_Challenge.Phase.ACTIVE
	state.elapsed = 0.0
	return true


static func begin_on_arrival(subject: Entity, actor: Entity) -> bool:
	if not _available(subject):
		return false
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	return (
		state != null and state.definition != null
		and state.definition.trigger == DEF_Challenge.Trigger.ON_ARRIVAL
		and arm(subject, actor) and activate(subject)
	)


static func request_departure(subject: Entity) -> void:
	if not is_instance_valid(subject):
		return
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	if (
		state != null and state.definition != null and state.phase == C_Challenge.Phase.ACTIVE
		and state.definition.completion in [DEF_Challenge.Completion.UNTIL_DEPARTURE, DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE]
	):
		state.departure_requested = true


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


static func tick(subject: Entity, state: C_Challenge, delta: float) -> void:
	if state == null or state.phase in [C_Challenge.Phase.INACTIVE, C_Challenge.Phase.CLEANUP]:
		return
	if not _valid_session(subject, state) or state.definition == null:
		cancel(subject)
		return
	if not is_finite(delta) or delta < 0.0:
		return
	match state.phase:
		C_Challenge.Phase.ARMED:
			return
		C_Challenge.Phase.ACTIVE:
			var previous_elapsed: float = state.elapsed
			state.elapsed += delta
			if state.definition.completion == DEF_Challenge.Completion.SURVIVE_DURATION:
				if state.definition.timeout_seconds > 0.0:
					state.elapsed = minf(state.elapsed, state.definition.timeout_seconds)
				_track_visit_condition(state, previous_elapsed)
				if state.condition_violated:
					_resolve(state, ChallengeResult.Type.FAILURE)
				elif state.definition.timeout_seconds > 0.0 and state.elapsed >= state.definition.timeout_seconds:
					_resolve(state, ChallengeResult.Type.SUCCESS)
			elif state.definition.completion in [DEF_Challenge.Completion.UNTIL_DEPARTURE, DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE]:
				_track_visit_condition(state, previous_elapsed)
				if state.condition_violated and state.definition.completion == DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE:
					_resolve(state, ChallengeResult.Type.FAILURE)
				elif state.departure_requested:
					var satisfied: bool = not state.condition_violated and (
						state.definition.completion == DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE
						or state.condition_result == ChallengeResult.Type.SUCCESS
					)
					_resolve(state, ChallengeResult.Type.SUCCESS if satisfied else ChallengeResult.Type.FAILURE)
			elif state.condition_result in [ChallengeResult.Type.SUCCESS, ChallengeResult.Type.FAILURE]:
				_resolve(state, state.condition_result)
			elif state.definition.timeout_seconds > 0.0 and state.elapsed >= state.definition.timeout_seconds:
				_resolve(state, ChallengeResult.Type.FAILURE)
		C_Challenge.Phase.SUCCESS, C_Challenge.Phase.FAILURE:
			state.result_remaining = maxf(0.0, state.result_remaining - delta)
			if state.result_remaining <= 0.0:
				_cleanup(subject, state)


static func cancel(subject: Entity) -> void:
	if not is_instance_valid(subject):
		return
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	if state == null or state.phase in [C_Challenge.Phase.INACTIVE, C_Challenge.Phase.CLEANUP]:
		return
	if state.result == ChallengeResult.Type.NONE:
		state.result = ChallengeResult.Type.CANCELLED
	_cleanup(subject, state)


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


static func result_for(subject: Entity) -> ChallengeResult.Type:
	if not is_instance_valid(subject):
		return ChallengeResult.Type.NONE
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	return state.result if state != null else ChallengeResult.Type.NONE


static func session_valid(subject: Entity) -> bool:
	if not _available(subject):
		return false
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	return state != null and _valid_session(subject, state)


static func _valid_session(subject: Entity, state: C_Challenge) -> bool:
	var cycle: C_DayCycle = DayPhaseService.current()
	return (
		_available(subject) and actor_for(subject) != null and cycle != null
		and cycle.day_index == state.started_day and cycle.phase == state.started_phase
	)


static func _available(entity: Entity) -> bool:
	return EntityAvailability.contains(entity, ECS.world) and not entity.has_component(C_Death)


static func _resolve(state: C_Challenge, result: ChallengeResult.Type) -> void:
	state.result = result
	state.phase = C_Challenge.Phase.SUCCESS if result == ChallengeResult.Type.SUCCESS else C_Challenge.Phase.FAILURE
	state.result_remaining = state.definition.result_display_seconds
	var event: ChallengeResolution = ChallengeResolution.new()
	event.challenge_key = state.definition.key
	event.result = result
	event.satisfaction_delta = state.definition.success_satisfaction_delta if result == ChallengeResult.Type.SUCCESS else state.definition.failure_satisfaction_delta
	event.request_escalation = result == ChallengeResult.Type.FAILURE and state.definition.escalation_on_failure
	state.pending_result = event


static func _track_visit_condition(state: C_Challenge, previous_elapsed: float) -> void:
	if state.condition_result == ChallengeResult.Type.SUCCESS:
		if state.definition.reset_violation_on_compliance:
			state.violation_elapsed = 0.0
		return
	var checked_seconds: float = maxf(0.0, state.elapsed - maxf(previous_elapsed, state.definition.preparation_seconds))
	state.violation_elapsed += checked_seconds
	if checked_seconds > 0.0 and (state.violation_elapsed >= state.definition.violation_grace_seconds or is_equal_approx(state.violation_elapsed, state.definition.violation_grace_seconds)):
		state.condition_violated = true


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
	ChallengeEffectLifecycle.retire(subject)
	for relation: Relationship in subject.relationships.duplicate():
		if relation.relation is R_ChallengeActor:
			subject.remove_relationship(relation)
