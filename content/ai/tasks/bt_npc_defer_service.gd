@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Переносит недоступный визит без потери, выдачи и денег.

## Причина переноса, показываемая игроку и записываемая в историю.
@export var reason: String = "Не удалось добраться до стойки"

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Перенести приход"):
		return FAILURE
	NpcServiceRole.defer_visit(_actor, _visit(), reason)
	return SUCCESS

#endregion
