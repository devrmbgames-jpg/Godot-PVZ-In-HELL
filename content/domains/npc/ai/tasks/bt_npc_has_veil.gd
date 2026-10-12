@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Ordinary actors skip the shared escape subtree.


#region Capability condition
func _tick(_delta: float) -> Status:
	return SUCCESS if NpcVeilQueries.rule_for(_person) != null else FAILURE
#endregion
