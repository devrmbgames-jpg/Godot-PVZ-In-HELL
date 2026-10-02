extends System
## Moves only nonphysical effect roots and applies explicit owner-loss policy.
class_name S_HazardFollow


func query() -> QueryBuilder:
	return q.enabled().with_relationship([Relationship.new(R_HazardFollow.new(), null)])


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
