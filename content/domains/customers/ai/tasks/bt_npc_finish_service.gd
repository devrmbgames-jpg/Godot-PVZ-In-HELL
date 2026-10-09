@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Снимает роль после завершившегося физического ухода.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Визит завершён"):
		return FAILURE
	NpcServiceRole.finish_appearance(_actor, _visit())
	return SUCCESS

#endregion
