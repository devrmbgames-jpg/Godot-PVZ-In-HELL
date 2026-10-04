extends System
## Планирует районный lifecycle до обслуживания, фаз дня и навигационных намерений.
class_name S_District

#region Планирование сервисного шага
## Размещает lifecycle района раньше обслуживания, смены фаз и навигации.
func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_CustomerFlow, S_DayPhase, S_NpcIntent] }

## Выбирает состояние района и общий цикл дня.
func query() -> QueryBuilder:
	return q.with_all([C_District, C_DayCycle]).iterate([C_District, C_DayCycle])

## Ставит синхронизацию расписания в CommandBuffer без собственного изменения компонентов.
func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	var districts: Array = components[0]
	var cycles: Array = components[1]
	for index: int in districts.size():
		cmd.add_custom(DistrictScheduleService.tick.bind(districts[index] as C_District, cycles[index] as C_DayCycle))
#endregion
