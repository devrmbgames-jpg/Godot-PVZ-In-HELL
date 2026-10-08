extends Observer
## Удаляет разрушенную неживую сущность только при явном маркере политики.
class_name O_RemoveOnHealthDepleted

## Подписывается на результат здоровья сущностей с явной политикой удаления.
func query() -> QueryBuilder:
	return q.with_all([C_RemoveOnHealthDepleted]).on_event(DamageResult.EVENT)

## Проверяет истощение конкретной цели и планирует её удаление.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if (
		result == null
		or result.outcome != DamageResult.Outcome.HEALTH_DEPLETED
		or result.request == null
		or result.request.target != entity
	):
		return

	var captured_policy: C_RemoveOnHealthDepleted = entity.get_component(C_RemoveOnHealthDepleted) as C_RemoveOnHealthDepleted
	cmd.add_custom(_remove.bind(weakref(entity), captured_policy))

func _remove(entity_reference: WeakRef, captured_policy: C_RemoveOnHealthDepleted) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not EntityAvailability.contains(entity, _world) \
			or entity.get_component(C_RemoveOnHealthDepleted) != captured_policy:
		return

	if not is_instance_valid(entity):
		return
	if EntityAvailability.contains(entity, _world):
		_world.remove_entity(entity)
	entity.queue_free()
