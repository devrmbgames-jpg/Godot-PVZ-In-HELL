@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Исполняющаяся атака сохраняет физический цикл и не запускается заново.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var combat: C_NpcCombat = _actor.get_component(C_NpcCombat) as C_NpcCombat
	return SUCCESS if combat != null and combat.phase != C_NpcCombat.Phase.READY else FAILURE
#endregion
