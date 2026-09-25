extends System
## Expires active deliberate-throw relationships using simulation time.
class_name S_ThrowLifetime


func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_Impact] }


func query() -> QueryBuilder:
	return q.enabled().with_all([C_ThrowDamage]).iterate([C_ThrowDamage])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for source: Entity in entities:
		var active: Relationship = ThrowContext.relationship(source)
		if active == null:
			continue
		var data: R_ThrownBy = active.relation as R_ThrownBy
		if data == null:
			cmd.add_custom(ThrowContext.cancel.bind(source))
			continue
		data.remaining_seconds = maxf(0.0, data.remaining_seconds - delta)
		if data.remaining_seconds <= 0.0:
			cmd.add_custom(ThrowContext.cancel.bind(source))
