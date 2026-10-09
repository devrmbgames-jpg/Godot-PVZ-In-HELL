@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Наблюдает занятие и видимого игрока, окликая не чаще одного раза за фазу.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Наблюдение"):
		return FAILURE
	NpcIntentArbiter.stop(_actor, intent_owner)
	NpcDecisionService.observe(_actor, _person, _awareness)
	return RUNNING

#endregion
