extends DEF_InteractionAction
class_name DEF_CarryPlacementAction


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CarryPlacementService.can_place(actor, source as E_PlacementArea)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CarryPlacementService.place(actor, source as E_PlacementArea)


func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CarryPlacementService.place(actor, source as E_PlacementArea)
