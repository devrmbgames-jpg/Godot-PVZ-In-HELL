extends System
## Schedules isolated first contact and captures the phase consumed once in this step.
class_name S_CustomerGreeting

#region Scheduling
## First contact precedes phase work, matching the existing introduction contract.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerClock], Runs.Before: [S_CustomerApproach, S_CustomerWaiting, S_CustomerInspection, S_CustomerDeparture]}


## District first contact is requested by its authored wait-for-parcel BT leaf.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent]).with_none([C_NpcIdentity, C_Death])


## Queues the request and phase snapshot together at this owner's buffer boundary.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for customer: Entity in entities:
		cmd.add_custom(_prepare.bind(customer))


func _prepare(customer: Entity) -> void:
	if not EntityAvailability.contains(customer, _world):
		return
	_world.emit_event(CustomerGreetingRequest.EVENT, customer, CustomerGreetingRequest.new())
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.scheduled_phase = int(agent.phase)
#endregion
