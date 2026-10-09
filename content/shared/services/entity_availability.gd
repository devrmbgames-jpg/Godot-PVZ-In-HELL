extends RefCounted
## Проверка действующего участия Entity в World без полномочий взаимодействия или урона.
class_name EntityAvailability


## true только для зарегистрированной, включённой Entity в дереве, не ожидающей удаления.
static func contains(candidate: Variant, world: World) -> bool:
	# Variant позволяет проверить уже освобождённый Object до приведения к Entity.
	if not is_instance_valid(candidate) or not candidate is Entity:
		return false

	var entity: Entity = candidate as Entity
	return (
		is_instance_valid(world) and entity.is_inside_tree() and not entity.is_queued_for_deletion()
		and entity.enabled and world.entity_to_archetype.has(entity)
	)
