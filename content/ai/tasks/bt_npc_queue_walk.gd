@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Проходит упорядоченные точки одного из двух авторских маршрутов.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Прогулка рядом с ПВЗ"):
		return FAILURE
	_move(NpcServiceRole.waiting_destination(_actor), NpcServiceRole.QUEUE_SPACING)
	return RUNNING

#endregion
