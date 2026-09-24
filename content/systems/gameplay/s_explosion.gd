extends System
## Resolves each independent explosion once; the damage channel may activate other emitters.
class_name S_Explosion


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_HazardFollow], Runs.Before: [S_HazardLifetime] }


func query() -> QueryBuilder:
	return q.enabled().with_all([C_Hazard, C_Explosion, C_HazardLifetime]).iterate(
		[C_Hazard, C_Explosion, C_HazardLifetime]
	)


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var hazards: Array = components[0]
	var explosions: Array = components[1]
	var lifetimes: Array = components[2]
	for index: int in entities.size():
		var explosion: C_Explosion = explosions[index]
		var hazard: C_Hazard = hazards[index]
		var lifetime: C_HazardLifetime = lifetimes[index]
		if explosion.resolved or lifetime.remaining_seconds <= 0.0:
			continue

		# Commit before any callback can publish damage/depletion or another spawn.
		explosion.resolved = true
		cmd.add_custom(ExplosionResolver.resolve.bind(entities[index], hazard, _world))
