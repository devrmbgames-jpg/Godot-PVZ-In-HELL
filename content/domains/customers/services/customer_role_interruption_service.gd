extends RefCounted
## Composes live role cleanup while retaining unresolved counter plans and home-delivery ownership.
class_name CustomerRoleInterruptionService


#region Explicit role interruption
## Releases interrupted execution; an unresolved counter order keeps its same-day visit plan.
static func suspend(body: E_DistrictNpc) -> void:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return

	var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
	var home: NpcHomeDelivery = HomeMeetingQueries.meeting_for(body)
	if visit == null:
		NpcServiceRole.release(body, agent.visit_id)
		return
	var home_outcome: bool = visit.actual in [
		CustomerVisit.Actual.DELIVERED,
		CustomerVisit.Actual.CUSTOMER_REFUSED,
	]
	if (
		(home != null and home_outcome)
		or (home == null and (visit.finished or visit.actual != CustomerVisit.Actual.NOT_RESOLVED))
	):
		if home != null:
			NpcHomeDeliveryService.complete(home)
		else:
			NpcServiceRole.finish_appearance(body, visit)
		return

	CustomerInspectionService.end(body)
	HomeMeetingBindings.release_meeting(body)
	visit.started = false
	if home == null:
		# Live role cleanup is not a missed collection: no deferred day, outcome or payment.
		visit.finished = false
	else:
		visit.finished = true
	NpcServiceRole.release(body, visit.visit_id)
#endregion
