@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Применяет существующую проверку и освобождает осмотр.

## Таймаут либо отсутствие коробки запрещает успешное принятие.
@export var force_refusal: bool = false

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Результат осмотра"):
		return FAILURE
	if force_refusal:
		_service().inspection_force_refusal = true
	CustomerFlowService.complete_inspection(_actor, _visit())
	return SUCCESS

#endregion
