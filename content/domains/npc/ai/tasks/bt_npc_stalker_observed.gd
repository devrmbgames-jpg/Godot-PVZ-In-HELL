@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Actual current camera visibility preempts hidden approach in the same native BT step.


#region Current visibility
func _tick(_delta: float) -> Status:
	var state: C_NpcStalking = _actor.get_component(C_NpcStalking) as C_NpcStalking
	var player: Entity = NpcGazeAversionSolver.visible_player(_actor)
	return (
		SUCCESS
		if player != null and state.rule != null
		and NpcStalkingSolver.observed(_actor, player, _actor.global_position, state.rule)
		else FAILURE
	)
#endregion
