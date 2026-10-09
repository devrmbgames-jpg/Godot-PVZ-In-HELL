@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Поиск ограничен последним наблюдением и авторским сроком.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if _awareness.has_last_seen and _awareness.search_elapsed < _person.profile.search_seconds else FAILURE
#endregion
