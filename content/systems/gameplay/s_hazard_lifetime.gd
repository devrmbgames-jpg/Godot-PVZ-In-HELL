extends System
## Удаляет истёкшие/отключённые опасности после последнего такта производителей урона.
class_name S_HazardLifetime


#region Scheduled hazard lifetime
## Выбирает все опасности с TTL, включая отключённые.
func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_HazardLifetime]).iterate([C_HazardLifetime])


## Уменьшает TTL в секундах вне ожидания эффекта и планирует удаление истёкших/отключённых.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return

	var lifetimes: Array = components[0]
	for index: int in entities.size():
		var lifetime: C_HazardLifetime = lifetimes[index]
		if not lifetime.awaiting_resolution:
			lifetime.remaining_seconds = maxf(0.0, lifetime.remaining_seconds - delta)
		if not entities[index].enabled or lifetime.remaining_seconds <= 0.0:
			cmd.add_custom(_retire_if_expired.bind(entities[index], lifetime, entities[index].get_component(C_Hazard) as C_Hazard))

#endregion

#region Captured expiry
func _retire_if_expired(effect: Entity, lifetime: C_HazardLifetime, hazard: C_Hazard) -> void:
	# Disabled effects deliberately participate in expiry; require registration without the active predicate.
	if not is_instance_valid(effect) or not effect.is_inside_tree() or effect.is_queued_for_deletion():
		return
	if not _world.entity_to_archetype.has(effect):
		return
	if effect.get_component(C_HazardLifetime) != lifetime or effect.get_component(C_Hazard) != hazard:
		return
	if not effect.enabled or lifetime.remaining_seconds <= 0.0:
		HazardLifecycle.retire(effect, _world)
#endregion
