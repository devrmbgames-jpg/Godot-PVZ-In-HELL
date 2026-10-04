@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Запрашивает существующую физическую выдачу настоящей коробки.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Принять коробку"):
		return FAILURE
	return SUCCESS if CustomerFlowService.try_automatic_handoff(_actor, _visit()) else FAILURE

#endregion
