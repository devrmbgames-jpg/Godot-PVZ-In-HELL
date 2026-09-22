extends DEF_InteractionAction
## Starts drawing through the resolver's existing physical-hand use mapping.
class_name DEF_MarkAction


func is_available(actor: Entity, source: Entity, target: Entity) -> bool:
	return S_Marker.can_begin(actor, source, target)


func execute(actor: Entity, source: Entity, target: Entity) -> void:
	S_Marker.begin(actor, source, target)
