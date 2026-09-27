extends Observer
## Generic cleanup policy for destructible non-living entities that opt in explicitly.
class_name O_RemoveOnHealthDepleted

func query() -> QueryBuilder:
	return q.with_all([C_RemoveOnHealthDepleted]).on_event(DamageResult.EVENT)

func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if (
		result == null
		or result.outcome != DamageResult.Outcome.HEALTH_DEPLETED
		or result.request == null
		or result.request.target != entity
	):
		return
	cmd.add_custom(_remove.bind(entity))

func _remove(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return
	if EntityAvailability.contains(entity, _world):
		_world.remove_entity(entity)
	entity.queue_free()
