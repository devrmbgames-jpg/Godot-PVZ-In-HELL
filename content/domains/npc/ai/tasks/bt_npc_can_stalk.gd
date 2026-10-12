@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Enables the native branch only before this player has noticed the selected capability.


#region Read-only decision guard
func _tick(_delta: float) -> Status:
	var player: Entity = NpcGazeAversionSolver.visible_player(_actor)
	return SUCCESS if NpcStalkingQueries.eligible(_actor, _person, player) else FAILURE
#endregion
