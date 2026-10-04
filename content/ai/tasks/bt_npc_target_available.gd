@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Проверяет участие противника в мире, без получения его скрытой позиции.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var target: Entity = CombatService.target_for(_actor)
	return SUCCESS if GrabService.holder_available(target) and not target.has_component(C_Death) else FAILURE
#endregion
