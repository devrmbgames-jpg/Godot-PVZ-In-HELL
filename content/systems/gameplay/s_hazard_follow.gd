extends System
## Перемещает только нефизические эффекты и применяет явную политику потери владельца.
class_name S_HazardFollow


## Выбирает включённые эффекты с живой связью следования.
func query() -> QueryBuilder:
	return q.enabled().with_relationship([Relationship.new(R_HazardFollow.new(), null)])


## Копирует позу только нефизического эффекта; потеря владельца снимает связь либо удаляет эффект.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var relationship: Relationship = HazardFollowService.binding(entity)
		if relationship == null:
			continue

		var follow: R_HazardFollow = relationship.relation as R_HazardFollow
		var effect: Node3D = entity as Node as Node3D
		if not EntityAvailability.contains(relationship.target, _world):
			if follow.on_loss == DEF_Hazard.OwnerLoss.Despawn:
				cmd.add_custom(HazardLifecycle.retire.bind(entity, _world))
			else:
				cmd.remove_relationship(entity, relationship)
			continue

		var origin: Node3D = relationship.target as Node3D
		if effect != null and origin != null and not effect is PhysicsBody3D:
			effect.global_transform = origin.global_transform * follow.local_offset
