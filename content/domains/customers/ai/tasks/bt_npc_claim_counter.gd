@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Резервирует свободную стойку и начинает единственный визит.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Подойти к стойке"):
		return FAILURE
	NpcServiceRole.claim_counter(_actor)
	return SUCCESS

#endregion
