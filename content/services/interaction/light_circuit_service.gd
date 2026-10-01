extends RefCounted
## Circuit component owns gameplay state; grouped Light3D nodes consume it.
class_name LightCircuitService


static func set_enabled(circuit: Entity, enabled: bool) -> bool:
	if not EntityAvailability.contains(circuit, ECS.world):
		return false
	var state: C_LightCircuit = circuit.get_component(C_LightCircuit) as C_LightCircuit
	if state == null:
		return false
	state.enabled = enabled
	sync(circuit, state)
	return true


static func sync(circuit: Entity, state: C_LightCircuit) -> void:
	if state == null:
		return
	for group_id: StringName in state.light_groups:
		for node: Node in circuit.get_tree().get_nodes_in_group(group_id):
			var light: Light3D = node as Light3D
			if light != null:
				light.visible = state.enabled


static func toggle(circuit: Entity) -> bool:
	if not EntityAvailability.contains(circuit, ECS.world):
		return false
	var state: C_LightCircuit = circuit.get_component(C_LightCircuit) as C_LightCircuit
	return state != null and set_enabled(circuit, not state.enabled)


static func is_enabled(circuit_id: StringName) -> bool:
	var state: C_LightCircuit = state_for(circuit_id)
	return state != null and state.enabled


static func state_for(circuit_id: StringName) -> C_LightCircuit:
	if not is_instance_valid(ECS.world):
		return null
	for circuit: Entity in ECS.world.query.with_all([C_LightCircuit]).execute():
		var state: C_LightCircuit = circuit.get_component(C_LightCircuit) as C_LightCircuit
		if state.circuit_id == circuit_id:
			return state
	return null
