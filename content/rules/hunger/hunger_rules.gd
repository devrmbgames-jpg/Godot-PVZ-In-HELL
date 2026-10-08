extends RefCounted
## Pure hunger tier/multiplier/policy calculations; S_Hunger owns growth and active time.
class_name HungerRules

const NEUTRAL_MULTIPLIER: float = 1.0


#region Ступени и множители
## Определяет ступень по политике и значению; отсутствие/неверная политика даёт NORMAL.
static func tier(state: C_Hunger) -> C_Hunger.Tier:
	if state == null or not valid_policy(state.policy):
		return C_Hunger.Tier.NORMAL
	if state.value >= state.policy.starving_threshold:
		return C_Hunger.Tier.STARVING
	return (
		C_Hunger.Tier.HUNGRY
		if state.value >= state.policy.hungry_threshold
		else C_Hunger.Tier.NORMAL
	)


## Проверяет хищное восприятие отдельно от ступеней скорости и боевого урона.
static func sees_npcs_as_food(state: C_Hunger) -> bool:
	return state != null and valid_policy(state.policy) and state.value / state.policy.maximum > state.policy.predatory_threshold


## Возвращает множитель текущей ступени без изменения голода.
static func speed_multiplier(state: C_Hunger) -> float:
	match tier(state):
		C_Hunger.Tier.HUNGRY:
			return state.policy.hungry_speed_multiplier

		C_Hunger.Tier.STARVING:
			return state.policy.starving_speed_multiplier
	return NEUTRAL_MULTIPLIER


## Возвращает множитель исходящего боевого урона текущей ступени.
static func damage_multiplier(state: C_Hunger) -> float:
	match tier(state):
		C_Hunger.Tier.HUNGRY:
			return state.policy.hungry_damage_multiplier

		C_Hunger.Tier.STARVING:
			return state.policy.starving_damage_multiplier
	return NEUTRAL_MULTIPLIER


#endregion

#region Authored policy validity
## Checks authored thresholds/ranges without mutating policy or runtime state.
static func valid_policy(policy: DEF_HungerPolicy) -> bool:
	if policy == null:
		return false

	for value: float in [policy.maximum, policy.hungry_threshold, policy.starving_threshold, policy.growth_per_second]:
		if not is_finite(value) or value < 0.0:
			return false

	for multiplier: float in [policy.hungry_speed_multiplier, policy.starving_speed_multiplier, policy.hungry_damage_multiplier, policy.starving_damage_multiplier]:
		if not is_finite(multiplier) or multiplier < NEUTRAL_MULTIPLIER:
			return false
	return policy.maximum >= policy.starving_threshold and policy.starving_threshold > policy.hungry_threshold and policy.hungry_threshold > 0.0

#endregion
