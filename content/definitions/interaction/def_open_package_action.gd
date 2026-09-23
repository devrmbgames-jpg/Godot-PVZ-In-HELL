extends DEF_InteractionAction
## Explicit contextual opening action; does not alter HP or enforce shipment ownership.
class_name DEF_OpenPackageAction


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return PackageOpening.can_open(actor, source)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	PackageOpening.request_open(actor, source)
