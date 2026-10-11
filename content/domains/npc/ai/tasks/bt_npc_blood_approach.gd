@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Request ordinary physical navigation toward an already perceived blood zone.


func _tick(_delta: float) -> Status:
	var zone: E_BloodArea = NpcBloodQueries.zone_for(_actor)
	if zone == null or not _claim("Подойти к крови"):
		return FAILURE
	_move(zone.global_position, NpcDecisionService.ARRIVAL_DISTANCE)
	NpcBloodService.mark_approach(_actor, zone, get_instance_id())
	return RUNNING
