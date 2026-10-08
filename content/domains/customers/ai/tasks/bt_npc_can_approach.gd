@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_condition.gd"
## Резервировать стойку может только первый ожидающий в открытой смене.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if NpcServiceRole.can_approach(_actor) else FAILURE
#endregion
