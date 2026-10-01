extends System
class_name S_RefusalQuest


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_DayPhase]}


func query() -> QueryBuilder:
	return q.with_all([C_QuestSession, C_DayCycle]).iterate([C_QuestSession, C_DayCycle])


func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	var states: Array = components[0]
	var cycles: Array = components[1]
	for index: int in states.size():
		cmd.add_custom(RefusalQuestService.tick.bind(states[index] as C_QuestSession, cycles[index] as C_DayCycle))
