@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Запрашивает личную реакцию после возврата; опасность/роли выше в корне дерева.


#region Leaf operation
func _tick(_delta: float) -> Status:
	if not _claim("Припомнить собственную смерть"):
		return FAILURE
	return SUCCESS if NpcCommunityService.react_to_return(_actor, _person) else FAILURE
#endregion
