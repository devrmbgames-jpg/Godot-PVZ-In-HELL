extends System
class_name S_NightSave


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase, S_WalletDay, S_CustomerFlow, S_RefusalQuest] }


func query() -> QueryBuilder:
	return q.with_all([C_DayCycle, C_Autosave]).iterate([C_DayCycle, C_Autosave])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var cycles: Array = components[0]
	var states: Array = components[1]
	for index: int in entities.size():
		cmd.add_custom(NightSaveService.process.bind(entities[index], cycles[index] as C_DayCycle, states[index] as C_Autosave, delta))
