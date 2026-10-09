@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Разрешает вход после выключения света.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Войти в ПВЗ"):
		return FAILURE
	NpcServiceRole.enter_counter(_actor)
	return SUCCESS

#endregion
