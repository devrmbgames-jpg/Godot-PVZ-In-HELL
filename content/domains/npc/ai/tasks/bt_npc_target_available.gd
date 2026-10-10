@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Проверяет участие противника в мире, без получения его скрытой позиции.


#region Проверка состояния
func _tick(_delta: float) -> Status:
	var target: Entity = CombatQueries.target_for(_actor)
	var target_available: bool = (
		GrabQueries.holder_available(target) and not target.has_component(C_Death)
	)
	return SUCCESS if target_available else FAILURE
#endregion
