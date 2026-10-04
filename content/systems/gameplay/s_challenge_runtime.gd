extends System
## После вычислителей условий продвигает общий жизненный цикл и публикует новый итог.
class_name S_ChallengeRuntime

## Новый принятый итог с живым участником, если связь ещё доступна.
signal resolved(subject: Entity, actor: Entity, event: ChallengeResolution)


## Разрешает итог после условий, фазы и обслуживания.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_ChallengeLight, S_ChallengeGaze, S_FloorHazard, S_DayPhase, S_CustomerFlow]}


## Выбирает общие состояния испытаний.
func query() -> QueryBuilder:
	return q.with_all([C_Challenge]).iterate([C_Challenge])


## Ставит продвижение жизненного цикла в CommandBuffer; delta в секундах.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var states: Array = components[0]
	for index: int in entities.size():
		cmd.add_custom(_step.bind(entities[index], states[index] as C_Challenge, delta))


func _step(subject: Entity, state: C_Challenge, delta: float) -> void:
	var previous: ChallengeResolution = state.pending_result
	ChallengeService.tick(subject, state, delta)
	if state.pending_result != null and state.pending_result != previous:
		resolved.emit(subject, ChallengeService.actor_for(subject), state.pending_result)
