extends System
## Синхронизирует автономную плоскость перед её воздействием и общим итогом.
class_name S_ChallengeFloorSetup


## Готовит эффект после фазы/обслуживания и до воздействия/итога.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_DayPhase], Runs.Before: [S_FloorHazard, S_ChallengeRuntime]}


## Выбирает испытания с данными плоского условия.
func query() -> QueryBuilder:
	return q.with_all([C_Challenge, C_FloorChallenge]).iterate([C_Challenge, C_FloorChallenge])


## Ставит синхронизацию плоскости с активным сеансом в CommandBuffer.
func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var states: Array = components[0]
	var floors: Array = components[1]
	for index: int in entities.size():
		cmd.add_custom(FloorChallengeService.synchronize.bind(entities[index], states[index] as C_Challenge, floors[index] as C_FloorChallenge))
