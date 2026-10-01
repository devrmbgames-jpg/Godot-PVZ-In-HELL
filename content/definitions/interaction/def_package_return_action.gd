extends DEF_InteractionAction
class_name DEF_PackageReturnAction


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return EntityAvailability.contains(source, ECS.world) and GrabService.within_pickup_reach(actor, source) and PackageReturnService.held_refused(actor) != null


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	if is_available(actor, source, null):
		PackageReturnService.return_held(actor)
