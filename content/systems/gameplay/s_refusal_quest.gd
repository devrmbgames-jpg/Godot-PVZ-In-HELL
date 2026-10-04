extends System
## После обслуживания и фаз планирует проверку исходов заданий через сервис.
class_name S_RefusalQuest


## Проверяет задания после обслуживания и изменения фаз.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_DayPhase]}


## Выбирает журнал заданий вместе с игровым циклом.
func query() -> QueryBuilder:
	return q.with_all([C_QuestSession, C_DayCycle]).iterate([C_QuestSession, C_DayCycle])


## Ставит проверку реальных исходов и наград в CommandBuffer.
func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	var states: Array = components[0]
	var cycles: Array = components[1]
	for index: int in states.size():
		cmd.add_custom(RefusalQuestService.tick.bind(states[index] as C_QuestSession, cycles[index] as C_DayCycle))
