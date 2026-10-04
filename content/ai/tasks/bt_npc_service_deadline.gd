@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Сравнивает часы роли с авторским параметром клиента.

## Имя существующего параметра DEF_Customer, содержащего длительность в секундах.
@export var seconds_property: StringName = &"patience_seconds"
## Нижняя граница времени для безопасного завершения ухода.
@export var minimum_seconds: float = 0.0

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var service: C_CustomerAgent = _service()
	var visit: CustomerVisit = _visit()
	if service == null or visit == null or visit.definition == null:
		return FAILURE
	var duration: float = float(visit.definition.get(seconds_property))
	return SUCCESS if service.elapsed >= maxf(minimum_seconds, duration) else FAILURE
#endregion
