@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Живой противник принадлежит Relationship, а не Blackboard.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if CombatService.target_for(_actor) != null else FAILURE
#endregion
