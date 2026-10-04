extends System
## Продвигает плоскую опасность сценарного испытания через FloorChallengeService.
class_name S_FloorHazard


## Исполняет плоскость после подготовки испытания и до его исхода/TTL.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_ChallengeFloorSetup], Runs.Before: [S_ChallengeRuntime, S_HazardLifetime]}


## Выбирает плоские опасности с общим определением.
func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_FloorHazard]).iterate([C_Hazard, C_FloorHazard])


## Ставит шаг сценарного сервиса плоскости в CommandBuffer; delta в секундах.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var hazards: Array = components[0]
	var effects: Array = components[1]
	for index: int in entities.size():
		cmd.add_custom(FloorChallengeService.step.bind(entities[index] as E_FloorHazard, hazards[index] as C_Hazard, effects[index] as C_FloorHazard, delta))
