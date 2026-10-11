@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Enables safe observation only for the selected capability and actually perceived player.


#region Observation eligibility
func _tick(_delta: float) -> Status:
	return (
		SUCCESS
		if _person.rule_for(DEF_NpcTrait.Kind.GAZE_AVERSION) is DEF_NpcGazeAversion \
				and NpcGazeAversionSolver.visible_player(_actor) != null
		else FAILURE
	)
#endregion
