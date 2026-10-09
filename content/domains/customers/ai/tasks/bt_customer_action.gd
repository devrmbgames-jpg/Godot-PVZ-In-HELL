@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Доступ к клиентской роли поверх общего контекста NPC; базовый NPC роль не читает.

#region Контекст обслуживания
func _visit() -> CustomerVisit:
	return CustomerFlowQueries.visit_for(_actor)

func _service() -> C_CustomerAgent:
	return _actor.get_component(C_CustomerAgent) as C_CustomerAgent
#endregion
