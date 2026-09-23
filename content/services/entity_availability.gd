extends RefCounted
## Neutral live-World membership checks; has no interaction or damage authority.
class_name EntityAvailability


## True only for enabled, registered Entities that are not leaving the scene tree.
static func contains(entity: Entity, world: World) -> bool:
	return (
		is_instance_valid(entity) and is_instance_valid(world)
		and entity.is_inside_tree() and not entity.is_queued_for_deletion()
		and entity.enabled and world.entity_to_archetype.has(entity)
	)
