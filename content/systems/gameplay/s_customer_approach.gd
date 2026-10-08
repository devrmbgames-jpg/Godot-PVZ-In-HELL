extends System
## Owns isolated approach phase progression; district decisions remain in the authored BT.
class_name S_CustomerApproach

#region Scheduling
## Runs after first contact and before challenge/day/navigation consumers.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerGreeting], Runs.Before: [S_ChallengeLight, S_ChallengeGaze, S_ChallengeRuntime, S_DayPhase, S_NpcDecision, S_NpcIntent]}


## Declares the phase snapshot consumed by this owner, excluding retained district bodies.
func query() -> QueryBuilder:
	var phases: Array[int] = [
		C_CustomerAgent.Phase.APPROACHING,
		C_CustomerAgent.Phase.WAITING_FOR_DARKNESS,
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

	match agent.phase:
		C_CustomerAgent.Phase.APPROACHING:
			if intent != null and intent.arrived:
				agent.phase = C_CustomerAgent.Phase.WAITING
				agent.elapsed = 0.0
				NpcIntentService.stop(customer)
				CustomerFlowService.watch_player(customer)
				if not agent.order_announced:
					customer.show_message("Здравствуйте!")
				var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
				if challenge != null and challenge.phase == C_Challenge.Phase.ACTIVE and not agent.order_announced:
					customer.show_message(challenge.definition.rule_text)
			elif agent.elapsed >= visit.definition.approach_timeout:
				CustomerFlowService.leave_service(customer, visit)
		C_CustomerAgent.Phase.WAITING_FOR_DARKNESS:
			var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
			var rule: DEF_LightChallengeCondition = CustomerArrivalService.darkness_rule(challenge)
			if rule == null or cycle.phase != C_DayCycle.Phase.DAY or challenge.result == ChallengeResult.Type.CANCELLED:
				CustomerFlowService.leave_service(customer, visit)
				return
			if LightCircuitService.is_enabled(rule.circuit_id) or challenge.result == ChallengeResult.Type.FAILURE:
				return

			var station: E_DeliveryCounter = CustomerFlowService.counter()
			if station == null:
				CustomerFlowService.leave_service(customer, visit)
				return
			agent.phase = C_CustomerAgent.Phase.APPROACHING
			agent.elapsed = 0.0
			NpcIntentService.move_to(customer, station.waiting_position(), visit.definition.arrival_distance)
			NpcIntentService.look_along_movement(customer)
			customer.show_message("Теперь я могу войти. Спасибо.")
#endregion
