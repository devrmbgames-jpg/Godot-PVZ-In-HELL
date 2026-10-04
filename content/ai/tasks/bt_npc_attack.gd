@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Запрашивает одну подходящую атаку, не меняя здоровье напрямую.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Атака видимой цели"):
		return FAILURE
	var choice: NpcAttackChoice = NpcAttackService.choose(_actor)
	if choice == null:
		return FAILURE
	NpcAttackService.start(_actor, choice.kind, choice.variant)
	return SUCCESS

#endregion
