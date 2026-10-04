@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Один раз запрашивает физическое вскрытие осматриваемой коробки.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Проверить содержимое"):
		return FAILURE
	CustomerInspectionService.inspect_contents(_actor, _visit())
	return RUNNING

#endregion
