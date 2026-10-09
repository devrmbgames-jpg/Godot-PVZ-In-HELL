extends RefCounted
## Общая линейная оценка Carry по физической массе и Strength держателя.
class_name CarryLoadPolicy

const MINIMUM_BASE_KG: float = 10.0
const MINIMUM_PER_STRENGTH_KG: float = 20.0
const MAXIMUM_BASE_KG: float = 90.0
const MAXIMUM_PER_STRENGTH_KG: float = 30.0


#region Масса и управление Carry
## Возвращает порог массы полного управления по Strength, в килограммах.
static func minimum_mass_kg(strength: C_Strength) -> float:
	return MINIMUM_BASE_KG + MINIMUM_PER_STRENGTH_KG * _strength_value(strength)


## Возвращает предельную массу Carry по Strength, в килограммах.
static func maximum_mass_kg(strength: C_Strength) -> float:
	return MAXIMUM_BASE_KG + MAXIMUM_PER_STRENGTH_KG * _strength_value(strength)


## Проверяет положительную конечную массу в кг и существующий Strength.
static func can_carry(mass_kg: float, strength: C_Strength) -> bool:
	if strength == null or not is_finite(mass_kg) or mass_kg <= 0.0:
		return false
	return mass_kg <= maximum_mass_kg(strength)


## Полное управление до minimum_mass_kg(), затем линейное снижение до нуля на maximum_mass_kg().
## Общий коэффициент меняет движение, поворот камеры/тела, вращение предмета и скорость броска.
static func mobility_multiplier(mass_kg: float, strength: C_Strength) -> float:
	if strength == null or not is_finite(mass_kg) or mass_kg <= 0.0:
		return 0.0

	var minimum: float = minimum_mass_kg(strength)
	var maximum: float = maximum_mass_kg(strength)
	if mass_kg <= minimum:
		return 1.0
	if mass_kg >= maximum:
		return 0.0
	return 1.0 - inverse_lerp(minimum, maximum, mass_kg)


## Возвращает коэффициент 1 без активного Carry, иначе ограничение по массе и Strength.
static func active_multiplier(carry_load: C_CarryLoad, strength: C_Strength) -> float:
	if carry_load == null or not carry_load.active:
		return 1.0
	return mobility_multiplier(carry_load.mass_kg, strength)


## Масштабирует неотрицательное базовое значение общим коэффициентом активного Carry.
static func scaled_value(
	base_value: float,
	carry_load: C_CarryLoad,
	strength: C_Strength,
) -> float:
	return maxf(base_value, 0.0) * active_multiplier(carry_load, strength)


static func _strength_value(strength: C_Strength) -> float:
	if strength == null or not is_finite(strength.value):
		return 0.0
	return maxf(strength.value, 0.0)

#endregion
