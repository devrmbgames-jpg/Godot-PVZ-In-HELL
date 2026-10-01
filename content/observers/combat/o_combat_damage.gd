extends Observer
## Records persistent attribution and reacts to a committed hit, never computes reputation.
class_name O_CombatDamage


func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent]).on_event(DamageResult.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result == null or result.applied_amount <= 0.0 or result.request == null or result.request.operation != DamageRequest.Operation.DAMAGE:
		return
	var context: CombatContext = result.request.combat_context
	if context == null:
		return
	var agent: C_CustomerAgent = entity.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	if visit != null:
		visit.last_combat_context = context
	if context.actor_is_player and result.outcome != DamageResult.Outcome.HEALTH_DEPLETED:
		cmd.add_custom(CustomerCombatService.retaliate.bind(entity, context))
