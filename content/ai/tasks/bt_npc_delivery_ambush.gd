@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Наблюдает авторский сценарий живой домашней встречи, не выбирая бой внутри условия.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if NpcDeliveryScenarioService.armed_for(_actor) != null else FAILURE
#endregion
