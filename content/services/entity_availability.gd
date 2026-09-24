extends RefCounted
## Neutral live-World membership checks; has no interaction or damage authority.
class_name EntityAvailability


## True only for enabled, registered Entities that are not leaving the scene tree.
static func contains(candidate: Variant, world: World) -> bool:
	# A freed Object cannot cross an Entity-typed parameter boundary in GDScript.
	if not is_instance_valid(candidate) or not candidate is Entity:
		return false

	var entity: Entity = candidate as Entity
	return (
		is_instance_valid(world) and entity.is_inside_tree() and not entity.is_queued_for_deletion()
		and entity.enabled and world.entity_to_archetype.has(entity)
	)
