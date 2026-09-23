extends System
## Expires deliberate-throw context using simulation time, independently of contact resolution.
class_name S_ThrowLifetime


func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_Impact] }


func query() -> QueryBuilder:
	return q.enabled().with_all([C_ThrowDamage]).iterate([C_ThrowDamage])


func process(_entities: Array[Entity], components: Array, delta: float) -> void:
	var contexts: Array = components[0]
	for context: C_ThrowDamage in contexts:
		context.remaining_seconds = maxf(0.0, context.remaining_seconds - delta)
		if context.remaining_seconds <= 0.0:
			context.instigator = null
