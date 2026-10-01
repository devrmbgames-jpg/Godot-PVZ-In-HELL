extends System
class_name S_ChallengeFloorSetup


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_DayPhase], Runs.Before: [S_FloorHazard, S_ChallengeRuntime]}


func query() -> QueryBuilder:
	return q.with_all([C_Challenge, C_FloorChallenge]).iterate([C_Challenge, C_FloorChallenge])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var states: Array = components[0]
	var floors: Array = components[1]
	for index: int in entities.size():
		cmd.add_custom(FloorChallengeService.synchronize.bind(entities[index], states[index] as C_Challenge, floors[index] as C_FloorChallenge))
