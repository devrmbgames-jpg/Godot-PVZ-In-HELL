extends DEF_InteractionAction
## Contextual take/release-handle action for transport carts, independent of Push.
class_name DEF_CartTransportAction

## Release addresses the active cart even when the player is not aiming at it.
@export var release_handle: bool = false


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if release_handle:
		return CartTransportService.current(actor) == source

	return CartTransportService.can_begin(actor, source)


func execute(actor: Entity, source: Entity, target: Entity) -> void:
	if not is_available(actor, source, target):
		return

	if release_handle:
		CartTransportService.end(source)
	else:
		CartTransportService.begin(actor, source)
