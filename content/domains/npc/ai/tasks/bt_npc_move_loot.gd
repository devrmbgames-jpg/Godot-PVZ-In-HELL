@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Двигается к воспринимаемому физическому предмету.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Подойти к добыче"):
		return FAILURE
	var loot: Entity = NpcCommunityService.loot_for(_actor)
	if loot == null:
		return FAILURE
	_move((loot as Node as Node3D).global_position, NpcPopulationQueries.current().definition.loot_distance)
	return RUNNING

#endregion
