extends DEF_ItemAccessProvider
## Both physical hands and Carry share the same authoritative R_HeldBy checks.
class_name DEF_HeldItemAccess


func items(actor: Entity) -> Array[Entity]:
	var result: Array[Entity] = []
	for slot: int in [C_Grabbable.HoldSlot.LEFT_HAND, C_Grabbable.HoldSlot.RIGHT_HAND, C_Grabbable.HoldSlot.CARRY]:
		var item: Entity = GrabService.held_in_slot(actor, slot)
		if GrabService.entity_available(item):
			result.append(item)
	return result


func can_consume(actor: Entity, item: Entity) -> bool:
	return GrabService.holder_available(actor) and items(actor).has(item)


func consume(actor: Entity, item: Entity) -> bool:
	if not can_consume(actor, item):
		return false
	GrabService.release(actor, item)
	ECS.world.remove_entity(item)
	return true
