extends RefCounted
## Circuit component owns gameplay state; grouped Light3D nodes consume it.
class_name LightCircuitService

static var _lookup_world: World = null
static var _circuit_query: QueryBuilder = null
static var _circuit_references: Dictionary[StringName, WeakRef] = {}

#region Circuit actions
## Sets and presents an enabled registered circuit.
static func set_enabled(circuit: Entity, enabled: bool) -> bool:
	if not EntityAvailability.contains(circuit, ECS.world):
		return false

	var state: C_LightCircuit = circuit.get_component(C_LightCircuit) as C_LightCircuit
	if state == null:
		return false

	state.enabled = enabled
	sync(circuit, state)
	return true

## Applies authoritative circuit state to its authored light groups.
static func sync(circuit: Entity, state: C_LightCircuit) -> void:
	if state == null:
		return

	for group_id: StringName in state.light_groups:
		for node: Node in circuit.get_tree().get_nodes_in_group(group_id):
			var light: Light3D = node as Light3D
			if light != null:
				var view: CircuitLightView = light.get_node_or_null("CircuitLightView") as CircuitLightView
				if view != null and not state.enabled:
					view.cancel_flicker()
				light.visible = state.enabled and (view == null or view.is_lit())

## Publishes a temporary visual flicker without toggling gameplay state.
static func flicker(circuit_id: StringName, duration: float, interval: float, request_id: StringName = &"") -> bool:
	var circuit: Entity = entity_for(circuit_id)
	if circuit == null or not is_enabled(circuit_id) or not is_finite(duration) or duration <= 0.0 or not is_finite(interval) or interval <= 0.0:
		return false

	var event: LightFlickerEvent = LightFlickerEvent.new()
	event.request_id = request_id
	event.circuit_id = circuit_id
	event.duration_seconds = duration
	event.interval_seconds = interval
	ECS.world.emit_event(LightFlickerEvent.EVENT, circuit, event)
	return true

## Stops the matching visual request for a circuit.
static func stop_flicker(circuit_id: StringName, request_id: StringName) -> void:
	var circuit: Entity = entity_for(circuit_id)
	if circuit == null:
		return

	var event: LightFlickerEvent = LightFlickerEvent.new()
	event.kind = LightFlickerEvent.Kind.STOP
	event.request_id = request_id
	event.circuit_id = circuit_id
	ECS.world.emit_event(LightFlickerEvent.EVENT, circuit, event)

## Changes a circuit through its stable authored ID.
static func set_by_id(circuit_id: StringName, enabled: bool) -> bool:
	return set_enabled(entity_for(circuit_id), enabled)

## Toggles an available circuit entity.
static func toggle(circuit: Entity) -> bool:
	if not EntityAvailability.contains(circuit, ECS.world):
		return false

	var state: C_LightCircuit = circuit.get_component(C_LightCircuit) as C_LightCircuit
	return state != null and set_enabled(circuit, not state.enabled)

#endregion

#region Circuit lookups
## Returns the authoritative switch state for a stable ID.
static func is_enabled(circuit_id: StringName) -> bool:
	var state: C_LightCircuit = state_for(circuit_id)
	return state != null and state.enabled

## Resolves current circuit data through a validated weak entity cache.
static func state_for(circuit_id: StringName) -> C_LightCircuit:
	var circuit: Entity = entity_for(circuit_id)
	return circuit.get_component(C_LightCircuit) as C_LightCircuit if circuit != null else null

## Finds a circuit without rebuilding an ECS query for each lamp/sample.
static func entity_for(circuit_id: StringName) -> Entity:
	if not is_instance_valid(ECS.world):
		return null
	if _lookup_world != ECS.world or not is_instance_valid(_lookup_world):
		_lookup_world = ECS.world
		_circuit_references.clear()
		_circuit_query = QueryBuilder.new(_lookup_world).with_all([C_LightCircuit])

	var reference: WeakRef = _circuit_references.get(circuit_id)
	var cached: Entity = reference.get_ref() as Entity if reference != null else null
	if cached != null and _lookup_world.entity_to_archetype.has(cached):
		var state: C_LightCircuit = cached.get_component(C_LightCircuit) as C_LightCircuit
		if state != null and state.circuit_id == circuit_id:
			return cached

	for circuit: Entity in _circuit_query.execute():
		var state: C_LightCircuit = circuit.get_component(C_LightCircuit) as C_LightCircuit
		_circuit_references[state.circuit_id] = weakref(circuit)
		if state.circuit_id == circuit_id:
			return circuit
	return null
#endregion
