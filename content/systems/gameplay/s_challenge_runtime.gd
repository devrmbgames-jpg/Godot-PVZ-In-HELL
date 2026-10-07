extends System
## Owns challenge elapsed/timeout/violation/display clocks after independent condition measurements.
class_name S_ChallengeRuntime

## Committed new result, provided its session still retains the result after synchronous consumers.
signal resolved(subject: Entity, actor: Entity, event: ChallengeResolution)

#region Scheduling
## Conditions and committed calendar/customer state precede lifecycle progression.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_ChallengeLight, S_ChallengeGaze, S_FloorHazard, S_DayPhase, S_CustomerFlow]}


## Selects live challenge owners; removed or dormant bodies do not consume time.
func query() -> QueryBuilder:
	return q.with_all([C_Challenge]).enabled()


## Captures component, phase and Definition identity before deferred execution.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for subject: Entity in entities:
		var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
		cmd.add_custom(_advance.bind(subject, state, state.phase, state.definition, delta))
#endregion

#region Authoritative clocks
func _advance(subject: Entity, captured: C_Challenge, phase: C_Challenge.Phase, definition: DEF_Challenge, delta: float) -> void:
	if not EntityAvailability.contains(subject, _world) or subject.get_component(C_Challenge) != captured:
		return
	if captured.phase != phase or captured.definition != definition:
		return

	var previous: ChallengeResolution = captured.pending_result
	_progress(subject, captured, delta)
	# Resolution observers can cancel the session or retire its owner synchronously.
	if EntityAvailability.contains(subject, _world) and subject.get_component(C_Challenge) == captured \
			and captured.pending_result != null and captured.pending_result != previous:
		resolved.emit(subject, ChallengeService.actor_for(subject), captured.pending_result)


func _progress(subject: Entity, state: C_Challenge, delta: float) -> void:
	if state.phase in [C_Challenge.Phase.INACTIVE, C_Challenge.Phase.CLEANUP]:
		return
	if not ChallengeService.session_valid(subject) or state.definition == null:
		ChallengeService.cancel(subject)
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
					ChallengeService.resolve(subject, ChallengeResult.Type.FAILURE)
				elif state.definition.timeout_seconds > 0.0 and state.elapsed >= state.definition.timeout_seconds:
					ChallengeService.resolve(subject, ChallengeResult.Type.SUCCESS)
			elif state.definition.completion in [DEF_Challenge.Completion.UNTIL_DEPARTURE, DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE]:
				_track_visit_condition(state, previous_elapsed)
				if state.condition_violated and state.definition.completion == DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE:
					ChallengeService.resolve(subject, ChallengeResult.Type.FAILURE)
				elif state.departure_requested:
					var satisfied: bool = not state.condition_violated and (
						state.definition.completion == DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE
						or state.condition_result == ChallengeResult.Type.SUCCESS
					)
					ChallengeService.resolve(subject, ChallengeResult.Type.SUCCESS if satisfied else ChallengeResult.Type.FAILURE)
			elif state.condition_result in [ChallengeResult.Type.SUCCESS, ChallengeResult.Type.FAILURE]:
				ChallengeService.resolve(subject, state.condition_result)
			elif state.definition.timeout_seconds > 0.0 and state.elapsed >= state.definition.timeout_seconds:
				ChallengeService.resolve(subject, ChallengeResult.Type.FAILURE)
		C_Challenge.Phase.SUCCESS, C_Challenge.Phase.FAILURE:
			state.result_remaining = maxf(0.0, state.result_remaining - delta)
			if state.result_remaining <= 0.0:
				ChallengeService.close(subject)



func _track_visit_condition(state: C_Challenge, previous_elapsed: float) -> void:
	if state.condition_result == ChallengeResult.Type.SUCCESS:
		if state.definition.reset_violation_on_compliance:
			state.violation_elapsed = 0.0
		return

	var checked_seconds: float = maxf(0.0, state.elapsed - maxf(previous_elapsed, state.definition.preparation_seconds))
	state.violation_elapsed += checked_seconds
	if checked_seconds > 0.0 and (state.violation_elapsed >= state.definition.violation_grace_seconds or is_equal_approx(state.violation_elapsed, state.definition.violation_grace_seconds)):
		state.condition_violated = true


#endregion
