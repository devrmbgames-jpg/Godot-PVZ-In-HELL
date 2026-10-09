extends RefCounted
## Чистая формула физического удара, независимая от расписания GECS и типа посылки.
class_name ImpactCalculation

const ENERGY_FACTOR: float = 0.5


## Оценивает направление: скорость в м/с и импульс в Н·с должны пройти пороги получателя.
static func evaluate(
	source_mass: float,
	normal_speed: float,
	normal_impulse: float,
	profile: DEF_ImpactProfile,
) -> ImpactResult:
	var result: ImpactResult = ImpactResult.new()
	if profile == null or not is_finite(source_mass) or source_mass <= 0.0:
		return result
	if not is_finite(normal_speed) or not is_finite(normal_impulse):
		return result
	if normal_speed <= 0.0 or normal_impulse <= 0.0:
		return result
	if normal_speed < profile.minimum_speed or normal_impulse < profile.minimum_impulse:
		return result

	var kinetic_energy: float = ENERGY_FACTOR * source_mass * normal_speed * normal_speed
	var contact_work: float = ENERGY_FACTOR * normal_impulse * normal_speed
	result.transferred_energy = minf(kinetic_energy, contact_work)
	result.amount = maxf(0.0, result.transferred_energy - profile.absorption_joules)
	result.amount *= maxf(0.0, profile.damage_per_joule)
	if not is_finite(result.amount):
		return ImpactResult.new()

	result.qualifies = true
	result.severity = classify(result.amount, profile)
	return result


## Классифицирует потенциальный урон с возможным бонусом действующего броска.
static func classify(amount: float, profile: DEF_ImpactProfile) -> ImpactResult.Severity:
	if amount <= 0.0:
		return ImpactResult.Severity.None
	if amount >= profile.strong_damage:
		return ImpactResult.Severity.Strong
	if amount >= profile.medium_damage:
		return ImpactResult.Severity.Medium
	return ImpactResult.Severity.Weak


## Ограничивает только численную потерю HP; тяжесть определяется до этого вызова.
static func cap_damage(amount: float, max_health: float, profile: DEF_ImpactProfile) -> float:
	if profile == null or not is_finite(amount) or not is_finite(max_health):
		return 0.0
	if amount <= 0.0 or max_health <= 0.0:
		return 0.0

	var maximum: float = max_health * clampf(profile.max_hp_fraction_per_hit, 0.0, 1.0)
	return minf(amount, maximum)
