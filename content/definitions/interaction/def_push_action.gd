extends DEF_InteractionAction
## Contextual start/stop command for cart Push; never acquires a Grab slot.
class_name DEF_PushAction

## Stop actions address the actor's current cart without requiring an aimed target.
@export var end_push: bool = false


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if end_push:
		return S_Push.pushed_object(actor) == source

	return S_Push.can_begin(actor, source)


func execute(actor: Entity, source: Entity, target: Entity) -> void:
	if not is_available(actor, source, target):
		return

	if end_push:
		S_Push.end(actor, source)
	else:
		S_Push.try_begin(actor, source)
