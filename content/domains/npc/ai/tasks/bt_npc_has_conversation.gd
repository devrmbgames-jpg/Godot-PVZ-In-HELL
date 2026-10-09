@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Разговор существует только пока сохранена живая связь участников.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if NpcDialogueService.participant(_actor) != null else FAILURE
#endregion
