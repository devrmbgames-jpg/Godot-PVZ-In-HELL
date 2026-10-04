extends Observer
## Typed world event relay. Room lamps subscribe to this signal.
class_name O_LightFlicker

signal flickering_light(event: LightFlickerEvent)


func query() -> QueryBuilder:
	return q.with_all([C_LightCircuit]).on_event(LightFlickerEvent.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var request: LightFlickerEvent = payload as LightFlickerEvent
	if request == null or not EntityAvailability.contains(entity, _world):
		return

	var state: C_LightCircuit = entity.get_component(C_LightCircuit) as C_LightCircuit
	if state != null and state.circuit_id == request.circuit_id and (state.enabled or request.kind == LightFlickerEvent.Kind.STOP):
		flickering_light.emit(request)
