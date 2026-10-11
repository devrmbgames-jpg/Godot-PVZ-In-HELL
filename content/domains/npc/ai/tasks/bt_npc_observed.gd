@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Reads the already sampled forced-freeze fact without casting new rays or mutating state.


#region Observation condition
func _tick(_delta: float) -> Status:
	return SUCCESS if is_instance_valid(_actor) and NpcGazeQueries.frozen(_actor) else FAILURE
#endregion
