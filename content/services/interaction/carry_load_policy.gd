extends RefCounted
## Shared linear Carry rule based only on physical mass and the holder's Strength.
class_name CarryLoadPolicy

const MINIMUM_BASE_KG: float = 10.0
const MINIMUM_PER_STRENGTH_KG: float = 20.0
const MAXIMUM_BASE_KG: float = 90.0
const MAXIMUM_PER_STRENGTH_KG: float = 30.0


static func minimum_mass_kg(strength: C_Strength) -> float:
	return MINIMUM_BASE_KG + MINIMUM_PER_STRENGTH_KG * _strength_value(strength)


static func maximum_mass_kg(strength: C_Strength) -> float:
	return MAXIMUM_BASE_KG + MAXIMUM_PER_STRENGTH_KG * _strength_value(strength)


static func can_carry(mass_kg: float, strength: C_Strength) -> bool:
	if strength == null or not is_finite(mass_kg) or mass_kg <= 0.0:
		return false
	return mass_kg <= maximum_mass_kg(strength)


## Full speed through minimum_mass_kg(), then linear to zero at maximum_mass_kg().
static func speed_multiplier(mass_kg: float, strength: C_Strength) -> float:
	if strength == null or not is_finite(mass_kg) or mass_kg <= 0.0:
		return 0.0
	var minimum: float = minimum_mass_kg(strength)
	var maximum: float = maximum_mass_kg(strength)
	if mass_kg <= minimum:
		return 1.0
	if mass_kg >= maximum:
		return 0.0
	return 1.0 - inverse_lerp(minimum, maximum, mass_kg)


static func _strength_value(strength: C_Strength) -> float:
	if strength == null or not is_finite(strength.value):
		return 0.0
	return maxf(strength.value, 0.0)
