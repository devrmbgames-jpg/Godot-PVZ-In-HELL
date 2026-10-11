@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Native Area overlap distinguishes retention from approach in the authored tree.


func _tick(_delta: float) -> Status:
	var zone: E_BloodArea = NpcBloodQueries.zone_for(_actor)
	return SUCCESS if zone != null and NpcBloodQueries.inside(_actor, zone) else FAILURE
