extends RefCounted
## Pure effective-damage calculation used by Health authority and NPC risk assessment.
class_name DamageResistanceRules

#region Damage calculation
## Resolves a receiver's resistance without applying damage.
static func effective(target: Entity, amount: float, damage_type: DamageRequest.Type) -> float:
	if not is_finite(amount) or amount <= 0.0:
		return 0.0
	var resistance: C_DamageResistance = target.get_component(C_DamageResistance) as C_DamageResistance if is_instance_valid(target) else null
	var multiplier: float = resistance.multipliers.get(damage_type, 1.0) if resistance != null else 1.0
	return amount * maxf(0.0, multiplier) if is_finite(multiplier) else amount
#endregion
