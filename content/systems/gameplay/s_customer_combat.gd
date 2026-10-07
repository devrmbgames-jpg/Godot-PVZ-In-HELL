extends System
## Owns isolated-customer challenge escalation and pursuit reconciliation before common attacks.
class_name S_CustomerCombat

## Existing authored-range midpoint used by isolated pursuit.
const RANGE_MIDPOINT_FRACTION: float = 0.5
## Existing fallback when no usable authored attack variant exists.
const DEFAULT_STOP_DISTANCE: float = 1.0

#region Scheduling
## Reconciles after customer/challenge commits and before common attack/intent execution.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_ChallengeRuntime], Runs.Before: [S_NpcCombat]}


## Retained district personalities remain exclusively under their native decision tree.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent, C_NpcCombat]).with_none([C_NpcIdentity]).enabled()


## Captures the current role identity; release/replacement rejects old queued escalation.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for customer: Entity in entities:
		var captured: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		cmd.add_custom(_advance.bind(customer, captured))
#endregion

#region Isolated escalation
func _advance(entity: Entity, captured: C_CustomerAgent) -> void:
	if not EntityAvailability.contains(entity, _world) or entity.get_component(C_CustomerAgent) != captured:
		return
	_reconcile(entity as E_Customer)


func _reconcile(customer: E_Customer) -> void:
	if customer.has_component(C_NpcIdentity):
		return

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	if visit == null or visit.finished or customer.has_component(C_Death):
		CombatService.end_combat(customer)
		return

	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	var state: C_NpcCombat = customer.get_component(C_NpcCombat) as C_NpcCombat
	if challenge != null and challenge.escalation_request != null:
		challenge.escalation_request = null
		if agent.phase not in [C_CustomerAgent.Phase.LEAVING, C_CustomerAgent.Phase.FINISHED]:
			visit.aggressive = true
			state.aggression_reason = CombatContext.Reason.CHALLENGE_ESCALATION
			CustomerFlowService.enter_aggressive(customer)
	if agent.phase != C_CustomerAgent.Phase.AGGRESSIVE:
		if CombatService.target_for(customer) != null:
			CombatService.end_combat(customer)
		return

	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if not GrabService.holder_available(player):
		CombatService.end_combat(customer)
		return
	if CombatService.target_for(customer) == player:
		return
	if visit.declaration == CustomerVisit.Declaration.TAKEN and visit.actual != CustomerVisit.Actual.DELIVERED:
		state.aggression_reason = CombatContext.Reason.FRAUD_ESCALATION
	if CombatService.bind_target(customer, player):
		ChallengeService.cancel(customer)
		GrabService.entity_unavailable(customer)
		NpcIntentService.follow(customer, player, _pursuit_stop_distance(state))
		NpcIntentService.watch(customer, player, Vector3.UP * CombatGeometry.GENERIC_TARGET_HEIGHT)
		customer.show_message("Я нападаю! Отойдите или защищайтесь.")


func _pursuit_stop_distance(state: C_NpcCombat) -> float:
	for attacks: Array[DEF_NpcAttack] in [state.melee_attacks, state.ranged_attacks]:
		for index: int in mini(attacks.size(), C_NpcCombat.MAX_VARIANTS):
			var attack: DEF_NpcAttack = attacks[index]
			if attack != null:
				return lerpf(attack.minimum_range, attack.maximum_range, RANGE_MIDPOINT_FRACTION)
	return DEFAULT_STOP_DISTANCE
#endregion
