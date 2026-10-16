@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Consumes one due social opportunity, including a durable skipped choice.


#region Explicit opportunity
func _tick(_delta: float) -> Status:
	var player: Entity = NpcGazeAversionSolver.visible_player(_actor)
	return SUCCESS if NpcStalkingService.begin(_actor, player) else FAILURE
#endregion
