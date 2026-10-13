extends Observer
## Distinguishes a called service approach failure from temporary waiting/emergency interruption.
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
			CustomerRoleInterruptionService.suspend(body)
		NpcRoleInterruptionRequest.Kind.ROUTE_BLOCKED:
			if HomeMeetingQueries.meeting_for(body) != null:
				CustomerRoleInterruptionService.suspend(body)
			elif visit != null:
				var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
				var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
				# Only the called recipient's actual approach can fail the collection trip.
				# Waiting-route and emergency movement timeouts leave the order due today.
				if (
					agent.phase == C_CustomerAgent.Phase.APPROACHING
					and decision.intent_owner == C_NpcDecision.Owner.SERVICE
					and not body.get_relationships(Relationship.new(
						R_NpcServiceAt.new(),
						CustomerFlowQueries.counter(),
					)).is_empty()
				):
					NpcServiceRole.defer_visit(body, visit, "Путь к ПВЗ недоступен")
		NpcRoleInterruptionRequest.Kind.EMERGENCY:
			CustomerRoleInterruptionService.suspend(body)
#endregion
