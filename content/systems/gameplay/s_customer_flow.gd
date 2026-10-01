extends System
class_name S_CustomerFlow


func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_DayPhase, S_NpcIntent] }


func query() -> QueryBuilder:
	return q.with_all([C_CustomerFlow, C_DayCycle]).iterate([C_CustomerFlow, C_DayCycle])


func process(_entities: Array[Entity], components: Array, delta: float) -> void:
	var flows: Array = components[0]
	var cycles: Array = components[1]
	for index: int in flows.size():
		cmd.add_custom(CustomerFlowService.tick.bind(flows[index], cycles[index], delta))
