extends System
class_name S_ChallengeRuntime

signal resolved(subject: Entity, actor: Entity, event: ChallengeResolution)


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_ChallengeLight, S_ChallengeGaze, S_DayPhase, S_CustomerFlow]}


func query() -> QueryBuilder:
	return q.with_all([C_Challenge]).iterate([C_Challenge])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var states: Array = components[0]
	for index: int in entities.size():
		cmd.add_custom(_step.bind(entities[index], states[index] as C_Challenge, delta))


func _step(subject: Entity, state: C_Challenge, delta: float) -> void:
	var previous: ChallengeResolution = state.pending_result
	ChallengeService.tick(subject, state, delta)
	if state.pending_result != null and state.pending_result != previous:
		resolved.emit(subject, ChallengeService.actor_for(subject), state.pending_result)
