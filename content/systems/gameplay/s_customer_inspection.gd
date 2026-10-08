extends System
## Owns isolated inspection phase progression; district decisions remain in the authored BT.
class_name S_CustomerInspection

#region Scheduling
## Runs after first contact and before challenge/day/navigation consumers.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerGreeting], Runs.Before: [S_ChallengeLight, S_ChallengeGaze, S_ChallengeRuntime, S_DayPhase, S_NpcDecision, S_NpcIntent]}


## Declares the phase snapshot consumed by this owner, excluding retained district bodies.
func query() -> QueryBuilder:
	var phases: Array[int] = [
		C_CustomerAgent.Phase.GOING_TO_BOOTH,
		C_CustomerAgent.Phase.INSPECTING,
		C_CustomerAgent.Phase.RETURNING_FROM_BOOTH,
	]
	return q.with_all([{C_CustomerAgent: {"scheduled_phase": {"_in": phases}}}]).with_none([C_NpcIdentity, C_Death])


## Queues one phase operation without advancing the shared clock again.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for customer: Entity in entities:
		var captured_agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		cmd.add_custom(_advance.bind(weakref(customer), captured_agent))


func _advance(entity_reference: WeakRef, captured_agent: C_CustomerAgent) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not EntityAvailability.contains(entity, _world) \
			or entity.get_component(C_CustomerAgent) != captured_agent:
		return

	var customer: E_Customer = entity as E_Customer
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if int(agent.phase) != agent.scheduled_phase:
		return
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	if visit == null:
		return
	var intent: C_NpcIntent = customer.get_component(C_NpcIntent) as C_NpcIntent

	if CustomerInspectionService.parcel_for(customer) == null:
		agent.inspection_force_refusal = true
		CustomerFlowService.complete_inspection(customer, visit)
		return

	match agent.phase:
		C_CustomerAgent.Phase.GOING_TO_BOOTH:
			if intent != null and intent.arrived:
				CustomerInspectionService.arrive(customer)
			elif agent.elapsed >= visit.definition.approach_timeout:
				CustomerInspectionService.return_to_service(customer, visit, true)
		C_CustomerAgent.Phase.INSPECTING:
			CustomerInspectionService.inspect_contents(customer, visit)
			if agent.elapsed >= visit.definition.inspection_seconds:
				CustomerInspectionService.return_to_service(customer, visit)
		C_CustomerAgent.Phase.RETURNING_FROM_BOOTH:
			if (intent != null and intent.arrived) or agent.elapsed >= visit.definition.approach_timeout:
				agent.inspection_force_refusal = intent == null or not intent.arrived or agent.inspection_force_refusal
				CustomerFlowService.complete_inspection(customer, visit)
#endregion
