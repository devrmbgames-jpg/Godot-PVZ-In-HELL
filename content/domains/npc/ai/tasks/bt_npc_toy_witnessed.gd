@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## A new physically witnessed toy provokes pride only without remembered respect for the player.


#region Sampled toy guard
func _tick(_delta: float) -> Status:
	return SUCCESS if NpcPrideQueries.pending_toy_incident(_actor, _person) != &"" else FAILURE
#endregion
