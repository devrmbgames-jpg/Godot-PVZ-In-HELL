extends RefCounted
## Explicit isolated-customer retaliation; S_CustomerCombat owns escalation/pursuit reconciliation.
class_name CustomerCombatService


## Запоминает принятый удар и запрашивает самозащиту прежнего живого клиента.
static func retaliate(customer: Entity, context: CombatContext) -> void:
	if customer.has_component(C_NpcIdentity):
		return

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or customer.has_component(C_Death):
		return

	var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
	if visit == null or visit.finished:
		return

	visit.last_combat_context = context
	visit.aggressive = true
	var state: C_NpcCombat = customer.get_component(C_NpcCombat) as C_NpcCombat
	if state != null:
		state.aggression_reason = CombatContext.Reason.SELF_DEFENSE
	CustomerFlowService.enter_aggressive(customer as E_NpcCharacter)
