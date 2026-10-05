@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Закрывает UI разговора и освобождает модальный ввод до запроса боя.

#region Запрос действия
func _tick(_delta: float) -> Status:
	NpcDialogueService.close_for(_actor)
	return SUCCESS
#endregion
