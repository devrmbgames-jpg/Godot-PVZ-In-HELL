@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Выбирает и запрашивает одну атаку; SUCCESS означает отправленную попытку, не урон или попадание.


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
