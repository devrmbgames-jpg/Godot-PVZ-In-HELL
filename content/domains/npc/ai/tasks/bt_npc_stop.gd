@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Останавливает участие терминального NPC без отмены чужого намерения.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Не участвует"):
		return FAILURE
	NpcIntentArbiter.stop(_actor, intent_owner)
	return RUNNING

#endregion
