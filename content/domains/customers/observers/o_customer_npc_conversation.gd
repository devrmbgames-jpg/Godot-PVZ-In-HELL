extends Observer
## Владелец клиентской роли разрешает уличный разговор только во время очереди.
class_name O_CustomerNpcConversation

#region Разрешение необязательной роли
## Реагирует на NPC query только при наличии текущей клиентской роли.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent]).on_event(NpcConversationPermissionRequest.EVENT)


## Возвращает разрешение синхронно, не меняя роль или связь разговора.
func each(_event: Variant, subject: Entity, payload: Variant = null) -> void:
	var request: NpcConversationPermissionRequest = payload as NpcConversationPermissionRequest
	assert(request != null)
	var agent: C_CustomerAgent = subject.get_component(C_CustomerAgent) as C_CustomerAgent
	request.allowed = agent.phase == C_CustomerAgent.Phase.QUEUED
#endregion
