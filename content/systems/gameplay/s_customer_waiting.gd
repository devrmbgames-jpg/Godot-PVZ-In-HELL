extends System
## Owns isolated waiting phase progression; district decisions remain in the authored BT.
class_name S_CustomerWaiting

#region Scheduling
## Runs after first contact and before challenge/day/navigation consumers.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerGreeting], Runs.Before: [S_ChallengeLight, S_ChallengeGaze, S_ChallengeRuntime, S_DayPhase, S_NpcDecision, S_NpcIntent]}


## Declares the phase snapshot consumed by this owner, excluding retained district bodies.
func query() -> QueryBuilder:
	var phases: Array[int] = [
		C_CustomerAgent.Phase.WAITING,
		C_CustomerAgent.Phase.WAITING_FOR_PACKAGE,
		C_CustomerAgent.Phase.DIALOGUE,
		C_CustomerAgent.Phase.OPTIONAL_FITTING,
		C_CustomerAgent.Phase.RECEIVING,
		C_CustomerAgent.Phase.AGGRESSIVE,
	]
	return q.with_all([{C_CustomerAgent: {"scheduled_phase": {"_in": phases}}}]).with_none([C_NpcIdentity, C_Death])


## Queues one phase operation without advancing the shared clock again.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for customer: Entity in entities:
		cmd.add_custom(_advance.bind(customer))


func _advance(entity: Entity) -> void:
	if not EntityAvailability.contains(entity, _world):
		return
	var customer: E_Customer = entity as E_Customer
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if int(agent.phase) != agent.scheduled_phase:
		return
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	if visit == null:
		return

	match agent.phase:
		C_CustomerAgent.Phase.WAITING:
			if CustomerFlowService.try_automatic_handoff(customer, visit):
				return
			if agent.elapsed >= visit.definition.greeting_seconds:
				CustomerFlowService.greet(customer)
		C_CustomerAgent.Phase.WAITING_FOR_PACKAGE, C_CustomerAgent.Phase.DIALOGUE, C_CustomerAgent.Phase.OPTIONAL_FITTING:
			if CustomerFlowService.try_automatic_handoff(customer, visit):
				return
			if agent.elapsed >= visit.definition.patience_seconds:
				CustomerFlowService.leave_service(customer, visit)
		C_CustomerAgent.Phase.RECEIVING:
			if agent.elapsed >= visit.definition.receiving_seconds:
				CustomerFlowService.leave_service(customer, visit)
		C_CustomerAgent.Phase.AGGRESSIVE:
			if agent.elapsed >= visit.definition.aggressive_seconds:
				CustomerFlowService.leave_service(customer, visit)
#endregion
