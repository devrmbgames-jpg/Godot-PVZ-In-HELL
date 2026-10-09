@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Снимает цель и память поиска после невозможности продолжать бой.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Завершить поиск"):
		return FAILURE
	CombatService.end_combat(_actor)
	_awareness.has_last_seen = false
	NpcIntentArbiter.stop(_actor, intent_owner)
	return SUCCESS

#endregion
