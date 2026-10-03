extends System
## Schedules district lifecycle before service and locomotion decisions.
class_name S_District

#region Scheduling
func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_CustomerFlow, S_DayPhase, S_NpcIntent] }

func query() -> QueryBuilder:
	return q.with_all([C_District, C_DayCycle]).iterate([C_District, C_DayCycle])

func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	var districts: Array = components[0]
	var cycles: Array = components[1]
	for index: int in districts.size():
		cmd.add_custom(DistrictScheduleService.tick.bind(districts[index] as C_District, cycles[index] as C_DayCycle))
#endregion
