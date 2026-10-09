extends RefCounted
## Owns the composed interruption transaction across service role and optional home delivery.
class_name CustomerRoleInterruptionService

#region Explicit role interruption
## Прерывает нерешённый визит, освобождая коробку и стойку без выдуманного результата.
static func suspend(body: E_DistrictNpc) -> void:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return

	var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
	var home: NpcHomeDelivery = HomeMeetingQueries.meeting_for(body)
	if visit == null:
		NpcServiceRole.release(body, agent.visit_id)
		return
	if visit.actual in [CustomerVisit.Actual.DELIVERED, CustomerVisit.Actual.CUSTOMER_REFUSED]:
		if home != null:
			NpcHomeDeliveryService.complete(home)
		else:
			NpcServiceRole.finish_appearance(body, visit)
		return

	CustomerInspectionService.end(body)
	HomeMeetingBindings.release_meeting(body)
	NpcServiceRole.release(body, visit.visit_id)
	if home == null:
		var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
		var reason: String = decision.active_behavior if decision != null else "опасность"
		NpcServiceRole.defer_visit(body, visit, "Приход прерван: " + reason)
	else:
		visit.started = false
		visit.finished = true
#endregion
