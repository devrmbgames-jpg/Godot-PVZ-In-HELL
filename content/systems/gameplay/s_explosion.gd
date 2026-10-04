extends System
## Разрешает каждый автономный взрыв один раз; результат урона может активировать другие emitter.
class_name S_Explosion


## Разрешает взрыв после следования и до удаления по TTL.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_HazardFollow], Runs.Before: [S_HazardLifetime] }


## Выбирает включённые взрывы с защитой разрешения и TTL.
func query() -> QueryBuilder:
	return q.enabled().with_all([C_Hazard, C_Explosion, C_HazardLifetime]).iterate(
		[C_Hazard, C_Explosion, C_HazardLifetime]
	)


## Фиксирует resolved до callback и ставит однократный расчёт в CommandBuffer.
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

		# Зафиксировать эффект до callback, урона, истощения и нового создания.
		explosion.resolved = true
		lifetime.awaiting_resolution = false
		cmd.add_custom(ExplosionResolver.resolve.bind(entities[index], hazard, _world))
