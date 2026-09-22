extends DEF_InteractionAction
class_name DEF_OpenDoorAction


## Implementations are stateless handlers. Mutable state belongs in Components.
func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
	return false


func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
	pass
