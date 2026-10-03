@tool
extends BTAction
## Small branch adapter; domain algorithms remain in NPC services.

## Branch priority and intent ownership requested by this task.
@export var owner_kind: C_NpcDecision.Owner = C_NpcDecision.Owner.IDLE

#region LimboAI callbacks
func _tick(delta: float) -> Status:
	var actor: E_DistrictNpc = get_agent() as E_DistrictNpc
	if not is_instance_valid(actor):
		return FAILURE
	return RUNNING if NpcDecisionService.execute_branch(actor, owner_kind, delta) else FAILURE

func _generate_name() -> String:
	return "NPC: " + C_NpcDecision.Owner.keys()[owner_kind]
#endregion
