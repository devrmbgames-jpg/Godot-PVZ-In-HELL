@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Проверяет окончательную смерть и временное отсутствие в районе.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if _person == null or _person.death_day != 0 or _person.placement != NpcRecord.Placement.STREET or _actor.has_component(C_Death) else FAILURE
#endregion
