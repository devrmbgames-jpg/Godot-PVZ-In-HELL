@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Проверяет участие противника в мире, без получения его скрытой позиции.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if GrabService.holder_available(CombatService.target_for(_actor)) else FAILURE
#endregion
