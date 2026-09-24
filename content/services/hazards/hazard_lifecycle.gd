extends RefCounted
## Shared retirement boundary; use through CommandBuffer while iterating GECS queries.
class_name HazardLifecycle


## Removes both registration and scene children, including disabled or already-unregistered effects.
static func retire(entity: Entity, world: World) -> void:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return

	if is_instance_valid(world) and world.entity_to_archetype.has(entity):
		world.remove_entity(entity)

	entity.queue_free()
