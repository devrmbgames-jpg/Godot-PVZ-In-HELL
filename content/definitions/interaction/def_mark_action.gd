extends DEF_InteractionAction
## Starts drawing through the resolver's existing physical-hand use mapping.
class_name DEF_MarkAction


func is_available(actor: Entity, source: Entity, target: Entity) -> bool:
	return MarkerSessionService.can_begin(actor, source, target)


func execute(actor: Entity, source: Entity, target: Entity) -> void:
	MarkerSessionService.begin(actor, source, target)
