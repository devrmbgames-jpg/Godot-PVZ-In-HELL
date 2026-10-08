@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Предмет можно забрать только на расстоянии взаимодействия.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var loot: Entity = NpcCommunityService.loot_for(_actor)
	var spatial: Node3D = loot as Node as Node3D
	return SUCCESS if spatial != null and _actor.global_position.distance_to(spatial.global_position) <= NpcPopulationQueries.current().definition.loot_distance else FAILURE
#endregion
