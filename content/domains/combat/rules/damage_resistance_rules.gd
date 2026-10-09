extends RefCounted
## Единый чистый расчёт эффективного урона для здоровья и оценки риска NPC.
class_name DamageResistanceRules

#region Расчёт урона
## Учитывает сопротивление получателя без изменения здоровья; иммунитет возвращает нулевой риск.
static func effective(target: Entity, amount: float, damage_type: DamageRequest.Type) -> float:
	if not is_finite(amount) or amount <= 0.0:
		return 0.0

	var resistance: C_DamageResistance = target.get_component(C_DamageResistance) as C_DamageResistance if is_instance_valid(target) else null
	var multiplier: float = resistance.multipliers.get(damage_type, 1.0) if resistance != null else 1.0
	return amount * maxf(0.0, multiplier) if is_finite(multiplier) else amount
#endregion
