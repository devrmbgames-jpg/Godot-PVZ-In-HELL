extends System
## Moves only nonphysical effect roots and applies explicit owner-loss policy.
class_name S_HazardFollow


func query() -> QueryBuilder:
	return q.enabled().with_all([R_HazardFollow]).iterate([R_HazardFollow])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var follows: Array = components[0]
	for index: int in entities.size():
		var follow: R_HazardFollow = follows[index]
		var effect: Node3D = entities[index] as Node as Node3D
		if not EntityAvailability.contains(follow.origin, _world):
			if follow.on_loss == DEF_Hazard.OwnerLoss.Despawn:
				cmd.add_custom(HazardLifecycle.retire.bind(entities[index], _world))
			else:
				cmd.remove_component(entities[index], R_HazardFollow)
			continue

		var origin: Node3D = follow.origin as Node as Node3D
		if effect != null and origin != null and not effect is PhysicsBody3D:
			effect.global_transform = origin.global_transform * follow.local_offset
