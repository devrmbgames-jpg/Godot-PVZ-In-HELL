extends RefCounted
## Pure generic impact formula; independent of GECS scheduling and Package type.
class_name ImpactCalculation

const ENERGY_FACTOR: float = 0.5


## Generic directional formula; both speed and real impulse must cross receiver thresholds.
static func evaluate(
	source_mass: float,
	normal_speed: float,
	normal_impulse: float,
	receiver: C_ImpactReceiver,
) -> ImpactResult:
	var result: ImpactResult = ImpactResult.new()
	if receiver == null or not is_finite(source_mass) or source_mass <= 0.0:
		return result
	if not is_finite(normal_speed) or not is_finite(normal_impulse):
		return result
	if normal_speed < receiver.minimum_speed or normal_impulse < receiver.minimum_impulse:
		return result

	var kinetic_energy: float = ENERGY_FACTOR * source_mass * normal_speed * normal_speed
	var contact_work: float = ENERGY_FACTOR * normal_impulse * normal_speed
	result.transferred_energy = minf(kinetic_energy, contact_work)
	result.amount = maxf(0.0, result.transferred_energy - receiver.absorption_joules)
	result.amount *= maxf(0.0, receiver.damage_per_joule)
	if result.amount > 0.0:
		result.severity = ImpactResult.Severity.Weak
	if result.amount >= receiver.medium_damage:
		result.severity = ImpactResult.Severity.Medium
	if result.amount >= receiver.strong_damage:
		result.severity = ImpactResult.Severity.Strong
	return result
