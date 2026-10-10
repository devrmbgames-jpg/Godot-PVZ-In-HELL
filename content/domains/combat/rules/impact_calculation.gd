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
	var impact: ImpactResult = ImpactResult.new()
	if profile == null or not is_finite(source_mass) or source_mass <= 0.0:
		return impact
	if not is_finite(normal_speed) or not is_finite(normal_impulse):
		return impact
	if normal_speed <= 0.0 or normal_impulse <= 0.0:
		return impact
	if normal_speed < profile.minimum_speed or normal_impulse < profile.minimum_impulse:
		return impact

	var kinetic_energy: float = ENERGY_FACTOR * source_mass * normal_speed * normal_speed
	var contact_work: float = ENERGY_FACTOR * normal_impulse * normal_speed
	impact.transferred_energy = minf(kinetic_energy, contact_work)
	impact.amount = maxf(0.0, impact.transferred_energy - profile.absorption_joules)
	impact.amount *= maxf(0.0, profile.damage_per_joule)
	if not is_finite(impact.amount):
		return ImpactResult.new()

	impact.qualifies = true
	impact.severity = classify(impact.amount, profile)
	return impact


## Классифицирует потенциальный урон с возможным бонусом действующего броска.
static func classify(amount: float, profile: DEF_ImpactProfile) -> ImpactResult.Severity:
	if amount <= 0.0:
		return ImpactResult.Severity.NONE
	if amount >= profile.strong_damage:
		return ImpactResult.Severity.STRONG
	if amount >= profile.medium_damage:
		return ImpactResult.Severity.MEDIUM
	return ImpactResult.Severity.WEAK


## Ограничивает только численную потерю HP; тяжесть определяется до этого вызова.
static func cap_damage(amount: float, max_health: float, profile: DEF_ImpactProfile) -> float:
	if profile == null or not is_finite(amount) or not is_finite(max_health):
		return 0.0
	if amount <= 0.0 or max_health <= 0.0:
		return 0.0

	var maximum: float = max_health * clampf(profile.max_hp_fraction_per_hit, 0.0, 1.0)
	return minf(amount, maximum)
