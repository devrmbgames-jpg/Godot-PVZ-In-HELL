@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_veil_action.gd"
## Escapes a real harmful zone using the existing route/physical intent owners.


#region Native cloud escape
func _tick(_delta: float) -> Status:
	if _route_abandoned():
		return FAILURE
	if not NpcRouteSolver.danger_here(_actor):
		return SUCCESS
	if not _claim_form(C_NpcVeil.Form.CLOUD, "Облаком из опасной зоны"):
		return FAILURE
	_move(NpcRouteSolver.refuge(_actor), NpcDecisionService.ARRIVAL_DISTANCE)
	return RUNNING
#endregion
