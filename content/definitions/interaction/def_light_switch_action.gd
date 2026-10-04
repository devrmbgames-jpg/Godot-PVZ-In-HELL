extends DEF_InteractionAction
class_name DEF_LightSwitchAction


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if not GrabService.holder_available(actor) or not EntityAvailability.contains(source, ECS.world):
		return false

	var interactable: C_Interactable = source.get_component(C_Interactable) as C_Interactable
	return (
		source.has_component(C_LightCircuit)
		and (interactable == null or interactable.enabled)
	)


func execute(actor: Entity, source: Entity, target: Entity) -> void:
	if is_available(actor, source, target):
		LightCircuitService.toggle(source)
