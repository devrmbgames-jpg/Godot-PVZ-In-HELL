extends System
## Планирует обслуживание через CustomerFlowService до фаз и исполнения навигационных намерений.
class_name S_CustomerFlow


## Обновляет обслуживание до S_DayPhase и исполнения S_NpcIntent.
func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_DayPhase, S_NpcIntent] }


## Выбирает сессию обслуживания вместе с её циклом дня.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerFlow, C_DayCycle]).iterate([C_CustomerFlow, C_DayCycle])


## Ставит шаг CustomerFlowService в CommandBuffer; delta задаётся в секундах.
func process(_entities: Array[Entity], components: Array, delta: float) -> void:
	var flows: Array = components[0]
	var cycles: Array = components[1]
	for index: int in flows.size():
		cmd.add_custom(CustomerFlowService.tick.bind(flows[index], cycles[index], delta))
