@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_condition.gd"
## Наблюдает одну группу фаз визита; переходы выбирает дерево.

## Наблюдаемые фазы роли; редактируются непосредственно в дереве.
@export var phases: Array[int] = []

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var service: C_CustomerAgent = _service()
	return SUCCESS if service != null and int(service.phase) in phases else FAILURE
#endregion
