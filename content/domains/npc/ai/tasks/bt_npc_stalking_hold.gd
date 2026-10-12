@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Holds position while visible or without a hidden route; interruption uses the native task token.


#region Stop request
func _tick(_delta: float) -> Status:
	if not _claim("Жуткий: удержать скрытную позицию"):
		return FAILURE
	_own_movement()
	NpcIntentArbiter.stop(_actor, intent_owner)
	return RUNNING
#endregion
