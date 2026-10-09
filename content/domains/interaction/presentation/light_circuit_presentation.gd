extends RefCounted
## Projects committed switch state onto authored Light3D groups without owning gameplay state.
class_name LightCircuitPresentation

#region Authored light projection
## Применяет состояние цепи к авторским группам света; выключение прекращает мерцание.
static func apply(circuit: Entity, state: C_LightCircuit) -> void:
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

#endregion
