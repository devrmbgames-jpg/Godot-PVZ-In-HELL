extends Observer
## Projects a committed switch fact immediately at the declared callback flush; periodic sync handles late lights.
class_name O_LightCircuitPresentation

#region Committed circuit consumption
## Watches the completed switch channel rather than requests or mutable UI state.
func query() -> QueryBuilder:
	return q.with_all([C_LightCircuit]).on_event(LightCircuitCommitted.EVENT)


## Captures Component/circuit/scalar identity before a queued presentation application.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var committed: LightCircuitCommitted = payload as LightCircuitCommitted
	if committed == null:
		return

	var state: C_LightCircuit = entity.get_component(C_LightCircuit) as C_LightCircuit
	cmd.add_custom(_apply.bind(weakref(entity), state, committed.circuit_id, committed.enabled))


func _apply(entity_reference: WeakRef, state: C_LightCircuit, circuit_id: StringName, enabled: bool) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not EntityAvailability.contains(entity, _world) or entity.get_component(C_LightCircuit) != state:
		return
	if state.circuit_id == circuit_id and state.enabled == enabled:
		LightCircuitPresentation.apply(entity, state)
#endregion
