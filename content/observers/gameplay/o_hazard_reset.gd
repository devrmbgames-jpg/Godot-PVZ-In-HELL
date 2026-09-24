extends Observer
## Consumes the generic reset event; future day/night systems need no package-specific cleanup.
class_name O_HazardReset


func query() -> QueryBuilder:
	return q.on_event(HazardResetRequest.EVENT)


func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var request: HazardResetRequest = payload as HazardResetRequest
	if request == null:
		return

	var hazards: Array = _world.query.with_all([C_Hazard, C_HazardLifetime]).execute()
	for hazard: Entity in hazards:
		var lifetime: C_HazardLifetime = hazard.get_component(C_HazardLifetime) as C_HazardLifetime
		if request.include_persistent or not lifetime.persistent:
			cmd.add_custom(HazardLifecycle.retire.bind(hazard, _world))
