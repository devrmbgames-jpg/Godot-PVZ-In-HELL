extends System
## Owns isolated appearance clocks; district clocks consume the native AI due-step fact.
class_name S_CustomerClock

#region Scheduling
## Clocks start after arrival and cleanup, before first contact and phase consumers.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_CustomerCleanup], Runs.Before: [S_CustomerGreeting, S_NpcDecision]}


## Selects live isolated appearances; retained district bodies have a separate cadence.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent]).with_none([C_NpcIdentity, C_Death])


## Queues a clock commit at this owner's structural buffer boundary.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	assert(is_finite(delta) and delta >= 0.0)
	for customer: Entity in entities:
		cmd.add_custom(_advance.bind(customer, delta))


func _advance(customer: Entity, delta: float) -> void:
	if not EntityAvailability.contains(customer, _world):
		return
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	if visit == null:
		return
	CustomerFlowService.bind_parcel(customer, visit)
	agent.elapsed += delta
	agent.scheduled_phase = -1
#endregion
