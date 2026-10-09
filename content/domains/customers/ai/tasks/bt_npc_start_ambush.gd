@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## По решению дерева запрашивает бой; здоровье меняется только существующим исполнением атак.

#region Запрос действия
func _tick(_delta: float) -> Status:
	if not _claim("Начать домашнюю засаду"):
		return FAILURE

	return SUCCESS if NpcDeliveryScenarioService.start_ambush(_actor) else FAILURE
#endregion
