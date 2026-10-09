extends RefCounted
## Общая граница удаления; при обходе GECS-запросов вызывается через CommandBuffer.
class_name HazardLifecycle


## Снимает регистрацию и удаляет узлы сцены, включая уже отключённый/незарегистрированный эффект.
static func retire(entity: Entity, world: World) -> void:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion():
		return

	if is_instance_valid(world) and world.entity_to_archetype.has(entity):
		world.remove_entity(entity)

	entity.queue_free()
