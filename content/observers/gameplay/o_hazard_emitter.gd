extends Observer
## Generic Health-depletion adapter for barrels, traps or any other emitter-bearing Entity.
class_name O_HazardEmitter


func query() -> QueryBuilder:
	return q.with_all([C_HazardEmitter]).on_event(DamageResult.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result == null or result.request == null:
		return

	if result.outcome != DamageResult.Outcome.HEALTH_DEPLETED:
		return

	if not is_instance_valid(entity):
		return

	var emitter: C_HazardEmitter = entity.get_component(C_HazardEmitter) as C_HazardEmitter
	if emitter.triggers & C_HazardEmitter.Trigger.HealthDepleted:
		var actor: Entity = result.request.instigator if is_instance_valid(
			result.request.instigator
		) else null
		if not is_instance_valid(actor) and result.request.instigator_id.is_empty():
			actor = result.request.source if is_instance_valid(result.request.source) else null
		HazardEmitter.activate(entity, actor, "", result.request.instigator_id)
