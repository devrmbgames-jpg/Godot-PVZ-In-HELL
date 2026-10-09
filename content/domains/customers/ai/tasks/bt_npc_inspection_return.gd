@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Начинает возвращение от кабинки, сохраняя груз и результат осмотра.

## Неудавшееся прибытие делает осмотр причиной отказа.
@export var force_refusal: bool = false

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Вернуться после осмотра"):
		return FAILURE
	CustomerInspectionService.return_to_service(_actor, _visit(), force_refusal)
	return SUCCESS

#endregion
