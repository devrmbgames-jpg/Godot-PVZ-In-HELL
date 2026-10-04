extends RefCounted
## Адаптер эскалации прежних клиентов к общему бою; постоянными NPC управляет районный AI.
class_name CustomerCombatService

const RANGE_MIDPOINT_FRACTION: float = 0.5
const DEFAULT_STOP_DISTANCE: float = 1.0


## Эскалирует только прежнего клиента, постоянного жителя пропускает.
static func tick(customer: E_Customer) -> void:
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


## Запоминает принятый удар и запрашивает самозащиту прежнего живого клиента.
static func retaliate(customer: Entity, context: CombatContext) -> void:
	if customer.has_component(C_NpcIdentity):
		return

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or customer.has_component(C_Death):
		return

	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	if visit == null or visit.finished:
		return

	visit.last_combat_context = context
	visit.aggressive = true
	var state: C_NpcCombat = customer.get_component(C_NpcCombat) as C_NpcCombat
	if state != null:
		state.aggression_reason = CombatContext.Reason.SELF_DEFENSE
	CustomerFlowService.enter_aggressive(customer as E_Customer)


static func _pursuit_stop_distance(state: C_NpcCombat) -> float:
	for attacks: Array[DEF_NpcAttack] in [state.melee_attacks, state.ranged_attacks]:
		for index: int in mini(attacks.size(), C_NpcCombat.MAX_VARIANTS):
			var attack: DEF_NpcAttack = attacks[index]
			if attack != null:
				return lerpf(attack.minimum_range, attack.maximum_range, RANGE_MIDPOINT_FRACTION)
	return DEFAULT_STOP_DISTANCE
