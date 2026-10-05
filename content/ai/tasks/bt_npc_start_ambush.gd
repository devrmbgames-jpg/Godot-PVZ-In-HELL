@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## По решению дерева запрашивает бой; здоровье меняется только существующим исполнением атак.

#region Запрос действия
func _tick(_delta: float) -> Status:
	return SUCCESS if NpcDeliveryScenarioService.start_ambush(_actor) else FAILURE
#endregion
