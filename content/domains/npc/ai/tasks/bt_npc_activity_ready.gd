@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Авторский интервал ограничивает смену свободной активности.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if _awareness.idle_elapsed >= NpcPopulationQueries.current().definition.activity_seconds else FAILURE
#endregion
