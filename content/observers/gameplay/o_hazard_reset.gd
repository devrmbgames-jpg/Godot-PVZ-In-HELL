extends Observer
## Обрабатывает общий сброс опасностей без специализированной очистки посылок.
class_name O_HazardReset


## Подписывается на общий запрос сброса опасностей.
func query() -> QueryBuilder:
	return q.on_event(HazardResetRequest.EVENT)


## Ставит удаление подходящих эффектов в CommandBuffer согласно include_persistent.
func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var request: HazardResetRequest = payload as HazardResetRequest
	if request == null:
		return

	var hazards: Array = _world.query.with_all([C_Hazard, C_HazardLifetime]).execute()
	for hazard: Entity in hazards:
		var lifetime: C_HazardLifetime = hazard.get_component(C_HazardLifetime) as C_HazardLifetime
		if request.include_persistent or not lifetime.persistent:
			cmd.add_custom(_retire.bind(weakref(hazard), lifetime))


#region Captured operation
func _retire(effect_reference: WeakRef, lifetime: C_HazardLifetime) -> void:
	# Disabled registered hazards also participate in the explicit reset operation.
	var effect: Entity = effect_reference.get_ref() as Entity
	if effect == null or not _world.entity_to_archetype.has(effect) or effect.is_queued_for_deletion():
		return
	if effect.get_component(C_HazardLifetime) != lifetime:
		return

	HazardLifecycle.retire(effect, _world)
#endregion
