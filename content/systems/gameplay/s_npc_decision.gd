extends System
## Schedules a bounded district sensory batch and native LimboAI decisions.
class_name S_NpcDecision

#region Scheduling
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_District, S_CustomerFlow], Runs.Before: [S_NpcCombat, S_NpcIntent] }

func query() -> QueryBuilder:
	return q.with_all([C_District]).iterate([C_District])

func process(_entities: Array[Entity], components: Array, delta: float) -> void:
	var districts: Array = components[0]
	for district: C_District in districts:
		cmd.add_custom(NpcBrainService.tick.bind(district, delta))
#endregion
