@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_veil_action.gd"
## Follows the ordinary authored portal flight; this leaf adds only cloud appearance.


#region Native flight
func _form() -> C_NpcVeil.Form:
	return C_NpcVeil.Form.CLOUD


func _tick(_delta: float) -> Status:
	if _route_abandoned():
		return FAILURE
	if not _claim_form(_form(), "Уход в скрытой форме"):
		return FAILURE
	return SUCCESS if NpcDecisionService.flee(_actor, _person, _awareness) else RUNNING
#endregion
