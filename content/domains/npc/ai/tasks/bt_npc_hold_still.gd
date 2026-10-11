@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Claims the safety branch and stops intent; native body/combat boundaries enforce the constraint.


#region Forced-freeze intent
func _tick(_delta: float) -> Status:
	if not _claim("Замер под взглядом"):
		return FAILURE
	_own_movement()
	NpcIntentArbiter.stop(_actor, intent_owner)
	return RUNNING
#endregion
