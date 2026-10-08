extends System
## Owns isolated departure phase progression; district decisions remain in the authored BT.
class_name S_CustomerDeparture

#region Scheduling
## Runs after first contact and before challenge/day/navigation consumers.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerGreeting], Runs.Before: [S_ChallengeLight, S_ChallengeGaze, S_ChallengeRuntime, S_DayPhase, S_NpcDecision, S_NpcIntent]}


## Declares the phase snapshot consumed by this owner, excluding retained district bodies.
func query() -> QueryBuilder:
	var phases: Array[int] = [
		C_CustomerAgent.Phase.LEAVING,
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
	var cycle: C_DayCycle = DayPhaseService.current()
	var intent: C_NpcIntent = customer.get_component(C_NpcIntent) as C_NpcIntent

	var departure_timeout: float = maxf(
		DEF_Customer.MINIMUM_LEAVING_SECONDS, visit.definition.leaving_seconds,
	)
	if (intent != null and intent.arrived) or agent.elapsed >= departure_timeout:
		ChallengeService.request_departure(customer)
		var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
		if challenge != null and challenge.definition != null:
			# Оценка света и применение результата идут после CustomerFlow.
			# Уходящий экземпляр живёт до обработки последнего условия этими владельцами.
			if challenge.phase == C_Challenge.Phase.ACTIVE and challenge.definition.completion in [DEF_Challenge.Completion.UNTIL_DEPARTURE, DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE]:
				return
			if challenge.pending_result != null and not challenge.consequences_applied:
				return

		agent.phase = C_CustomerAgent.Phase.FINISHED
		agent.elapsed = 0.0
		CustomerFlowService.finish(visit, cycle.day_index)
		CustomerFlowService.remove_appearance(customer, visit)
#endregion
