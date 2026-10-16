@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Enables one due opportunity or its still-valid captured episode; memory is historical only.


#region Read-only decision guard
func _tick(_delta: float) -> Status:
	var player: Entity = NpcGazeAversionSolver.visible_player(_actor)
	return SUCCESS if NpcStalkingQueries.eligible(_actor, _person, player) else FAILURE
#endregion
