extends System
## Записывает измерение взгляда и публикует предупреждение до общего разрешения испытания.
class_name S_ChallengeGaze


## Измеряет взгляд после обслуживания и до общего итога.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow], Runs.Before: [S_ChallengeRuntime]}


## Выбирает испытания с производным измерением взгляда.
func query() -> QueryBuilder:
	return q.with_all([C_Challenge, C_GazeChallenge]).iterate([C_Challenge, C_GazeChallenge])


## Обновляет измерение и предупреждение, не принимая общий итог самостоятельно.
func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var states: Array = components[0]
	var observations: Array = components[1]
	for index: int in entities.size():
		var state: C_Challenge = states[index] as C_Challenge
		var observation: C_GazeChallenge = observations[index] as C_GazeChallenge
		var rule: DEF_GazeChallengeCondition = state.definition.condition as DEF_GazeChallengeCondition if state.definition != null else null
		if state.phase != C_Challenge.Phase.ACTIVE or rule == null:
			GazeTrackingGeometry.clear(observation)
			observation.warning_active = false
			continue

		GazeTrackingGeometry.sample(ChallengeService.actor_for(entities[index]), entities[index], rule, observation)
		state.condition_result = ChallengeResult.Type.SUCCESS if observation.sample_valid and observation.attention == rule.required_attention else ChallengeResult.Type.NONE
		var warning: bool = (
			state.condition_result != ChallengeResult.Type.SUCCESS
			and state.elapsed >= state.definition.preparation_seconds
			and state.violation_elapsed >= state.definition.violation_grace_seconds * rule.warning_fraction
		)
		if warning != observation.warning_active:
			observation.warning_active = warning
			var customer: E_Customer = entities[index] as E_Customer
			if customer != null:
				customer.show_message(rule.warning_text if warning else state.definition.rule_text)
