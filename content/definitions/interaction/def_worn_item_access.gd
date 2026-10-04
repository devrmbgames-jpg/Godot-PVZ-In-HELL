extends DEF_ItemAccessProvider
## Access to concrete items in slots mounted on this actor via Relationships.
class_name DEF_WornItemAccess


func items(actor: Entity) -> Array[Entity]:
	return PhysicalSlotService.worn_items(actor)


func can_consume(actor: Entity, item: Entity) -> bool:
	return items(actor).has(item)


func consume(actor: Entity, item: Entity) -> bool:
	if not can_consume(actor, item):
		return false

	PhysicalSlotService.release(item)
	ECS.world.remove_entity(item)
	return true
