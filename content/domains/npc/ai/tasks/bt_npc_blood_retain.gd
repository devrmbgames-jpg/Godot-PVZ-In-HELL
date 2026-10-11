@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Retain through native overlap, releasing movement when interrupted by another branch.


func _tick(_delta: float) -> Status:
	var zone: E_BloodArea = NpcBloodQueries.zone_for(_actor)
	if zone == null or not _claim("Оставаться у крови"):
		return FAILURE
	_own_movement()
	NpcIntentArbiter.stop(_actor, intent_owner)
	return RUNNING
