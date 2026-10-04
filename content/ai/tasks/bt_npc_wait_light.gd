@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Предупреждает один раз и ожидает снаружи, не меняя выключатель.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Жду выключения света"):
		return FAILURE
	NpcServiceRole.warn_light(_actor)
	_move(CustomerFlowService.counter().entry_position(), NpcServiceRole.QUEUE_SPACING)
	return RUNNING

#endregion
