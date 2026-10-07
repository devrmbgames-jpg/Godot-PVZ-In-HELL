extends System
## Cleans orphaned and deceased appearances without choosing a living customer's phase.
class_name S_CustomerCleanup

#region Scheduling
## Cleanup precedes every clock and native service decision.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow], Runs.Before: [S_CustomerClock, S_NpcDecision]}


## Selects both isolated appearances and service roles on retained NPC bodies.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent])


## Queues terminal cleanup; death provenance may have crossed a stored-reference boundary.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for customer: Entity in entities:
		cmd.add_custom(_cleanup.bind(customer))


func _cleanup(customer: Entity) -> void:
	if not EntityAvailability.contains(customer, _world):
		return
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	var death: C_Death = customer.get_component(C_Death) as C_Death
	if visit != null and death == null:
		return

	CustomerInspectionService.end(customer)
	if visit != null:
		visit.customer_dead = true
		if death.cause != null and death.cause.request != null:
			var actor: Entity = death.cause.request.instigator
			if not is_instance_valid(actor):
				actor = death.cause.request.source
			visit.defeated_by_player = is_instance_valid(actor) and actor.has_component(C_PlayerInputController)
		CustomerFlowService.finish(visit, DayPhaseService.current().day_index)
	CustomerFlowService.remove_appearance(customer as E_Customer, visit)
#endregion
