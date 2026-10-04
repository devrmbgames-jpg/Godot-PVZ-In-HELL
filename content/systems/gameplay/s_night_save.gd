extends System
## После фаз и расчётов ставит ночную подготовку/сохранение в CommandBuffer.
class_name S_NightSave


## Исполняется после фаз, кошелька, обслуживания и заданий для согласованного результата.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase, S_WalletDay, S_CustomerFlow, S_RefusalQuest] }


## Выбирает сессии с игровым циклом и состоянием автосохранения.
func query() -> QueryBuilder:
	return q.with_all([C_DayCycle, C_Autosave]).iterate([C_DayCycle, C_Autosave])


## Ставит подготовку и повтор записи в CommandBuffer; delta задаётся в секундах.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var cycles: Array = components[0]
	var states: Array = components[1]
	for index: int in entities.size():
		cmd.add_custom(NightSaveService.process.bind(entities[index], cycles[index] as C_DayCycle, states[index] as C_Autosave, delta))
