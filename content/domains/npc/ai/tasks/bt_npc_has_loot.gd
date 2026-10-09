@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Отношение с доступной добычей остаётся единственной живой целью.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if NpcCommunityService.loot_for(_actor) != null else FAILURE
#endregion
