extends RefCounted
## Общая проверка настроек создания/загрузки без изменения авторского определения.
class_name HazardProfileRules


## Проверяет конечный TTL и поддерживаемые параметры токсичной зоны/взрыва без изменения данных.
static func valid(definition: DEF_Hazard) -> bool:
	if definition == null or not _positive(definition.lifetime_seconds):
		return false
	if definition is DEF_ToxicArea:
		var toxin: DEF_ToxicArea = definition as DEF_ToxicArea
		return _positive(toxin.radius) and _positive(toxin.tick_seconds) and _nonnegative(toxin.damage_per_tick)
	if definition is DEF_Explosion:
		var blast: DEF_Explosion = definition as DEF_Explosion
		return _positive(blast.radius) and _positive(blast.falloff_power) and _nonnegative(blast.damage) and _nonnegative(blast.impulse) and _nonnegative(blast.upward_bias) and blast.maximum_targets > 0
	return true


static func _positive(value: float) -> bool:
	return is_finite(value) and value > 0.0


static func _nonnegative(value: float) -> bool:
	return is_finite(value) and value >= 0.0
