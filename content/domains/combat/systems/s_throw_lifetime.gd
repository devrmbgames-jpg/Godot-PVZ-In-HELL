extends System
## Уменьшает срок атрибуции броска и снимает R_ThrownBy после истечения.
class_name S_ThrowLifetime


## Уменьшает срок до оценки нового столкновения в S_Impact.
func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_Impact] }


## Выбирает источники с настройками бонуса броска.
func query() -> QueryBuilder:
	return q.enabled().with_all([C_ThrowDamage]).iterate([C_ThrowDamage])


## Уменьшает срок в секундах и планирует снятие истёкшей либо повреждённой атрибуции.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for source: Entity in entities:
		var active: Relationship = ThrowContext.relationship(source)
		if active == null:
			continue

		var data: R_ThrownBy = active.relation as R_ThrownBy
		if data == null:
			cmd.add_custom(_cancel_expired.bind(weakref(source), active))
			continue

		data.remaining_seconds = maxf(0.0, data.remaining_seconds - delta)
		if data.remaining_seconds <= 0.0:
			cmd.add_custom(_cancel_expired.bind(weakref(source), active))


#region Captured operation
func _cancel_expired(source_reference: WeakRef, captured: Relationship) -> void:
	var source: Entity = source_reference.get_ref() as Entity
	if not EntityAvailability.contains(source, _world) or ThrowContext.relationship(source) != captured:
		return

	ThrowContext.cancel(source)
#endregion
