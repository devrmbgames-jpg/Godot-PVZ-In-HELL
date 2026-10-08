extends Observer
## Сохраняет атрибуцию и реагирует на принятый удар; общую репутацию не рассчитывает.
class_name O_CombatDamage


## Наблюдает фактический результат урона обслуживаемых клиентов.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent]).on_event(DamageResult.EVENT)


## Сохраняет боевой контекст визита и планирует ответ прежнего клиента на нелетальный удар.
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
		cmd.add_custom(_retaliate.bind(weakref(entity), agent, context))


#region Captured operation
func _retaliate(customer_reference: WeakRef, agent: C_CustomerAgent, context: CombatContext) -> void:
	var customer: Entity = customer_reference.get_ref() as Entity
	if not EntityAvailability.contains(customer, _world) or customer.get_component(C_CustomerAgent) != agent:
		return

	CustomerCombatService.retaliate(customer, context)
#endregion
