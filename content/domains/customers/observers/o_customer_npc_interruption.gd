extends Observer
## Клиентский владелец освобождает роль по синхронному запросу общего NPC AI.
class_name O_CustomerNpcInterruption

#region Граница необязательной роли
## Выбирает только текущую роль; NPC без неё сохраняет обычное поведение расписания.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent]).on_event(NpcRoleInterruptionRequest.EVENT)


## Завершает клиентское прерывание до продолжения NPC lifecycle; структурные изменения синхронны.
func each(_event: Variant, subject: Entity, payload: Variant = null) -> void:
	var request: NpcRoleInterruptionRequest = payload as NpcRoleInterruptionRequest
	assert(request != null)
	var body: E_DistrictNpc = subject as E_DistrictNpc
	var visit: CustomerVisit = CustomerFlowQueries.visit_for(body)
	request.handled = true

	match request.kind:
		NpcRoleInterruptionRequest.Kind.FLEE_EXIT:
			if visit != null:
				NpcServiceRole.finish_appearance(body, visit)
		NpcRoleInterruptionRequest.Kind.ROUTE_BLOCKED:
			if HomeMeetingQueries.meeting_for(body) != null:
				CustomerRoleInterruptionService.suspend(body)
			elif visit != null:
				NpcServiceRole.defer_visit(body, visit, "Путь к ПВЗ недоступен")
		NpcRoleInterruptionRequest.Kind.EMERGENCY:
			CustomerRoleInterruptionService.suspend(body)
#endregion
