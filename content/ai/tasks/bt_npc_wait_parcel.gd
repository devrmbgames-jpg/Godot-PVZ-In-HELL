@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Ожидает коробку; знакомство не перезапускает диалог и номер.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Жду посылку"):
		return FAILURE
	NpcIntentArbiter.stop(_actor, intent_owner)
	CustomerGreetingService.tick(_actor, _visit())
	return RUNNING

#endregion
