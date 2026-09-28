extends DEF_InteractionAction
## Author separate Open/Close/Unlock entries with matching captions in an action set.
class_name DEF_OpenableAction

@export var operation: OpenableService.Operation = OpenableService.Operation.OPEN


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return OpenableService.can_request(actor, source, operation)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	OpenableService.request(actor, source, operation)


func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	return OpenableService.request(actor, source, operation)
