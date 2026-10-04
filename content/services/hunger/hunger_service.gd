extends RefCounted
## Владеет ростом голода и эффектом питания, возвращает множители без изменения авторских данных.
class_name HungerService

const NEUTRAL_MULTIPLIER: float = 1.0


#region Ступени и множители
## Определяет ступень по политике и значению; отсутствие/неверная политика даёт NORMAL.
static func tier(state: C_Hunger) -> C_Hunger.Tier:
	if state == null or not _valid_policy(state.policy):
		return C_Hunger.Tier.NORMAL
	if state.value >= state.policy.starving_threshold:
		return C_Hunger.Tier.STARVING
	return C_Hunger.Tier.HUNGRY if state.value >= state.policy.hungry_threshold else C_Hunger.Tier.NORMAL


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

#region Рост и питание
## Увеличивает голод и активное время при живом участнике вне паузы/ночи; delta в секундах.
static func advance(state: C_Hunger, delta: float, phase: C_DayCycle.Phase, paused: bool, alive: bool) -> void:
	if state == null or not _valid_policy(state.policy) or not is_finite(delta) or delta <= 0.0 or paused or not alive or phase == C_DayCycle.Phase.NIGHT:
		return

	state.value = clampf(state.value + delta * state.policy.growth_per_second, 0.0, state.policy.maximum)
	state.active_seconds += delta


## Проверяет текущую фазу и доступность участника, затем продвигает голод.
static func tick(actor: Entity, delta: float, state: C_Hunger = null) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	if state == null:
		state = actor.get_component(C_Hunger) as C_Hunger
	advance(state, delta, cycle.phase, actor.get_tree().paused, GrabService.holder_available(actor) and not actor.has_component(C_Death))


## Явно задаёт допустимый уровень через ту же проверку доступности и границ, что у еды.
static func set_value(actor: Entity, value: float) -> bool:
	if not GrabService.holder_available(actor) or actor.has_component(C_Death):
		return false

	var state: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	if state == null or not _valid_policy(state.policy) or not is_finite(value) or value < 0.0 or value > state.policy.maximum:
		return false

	state.value = value
	return true


## Уменьшает положительный голод доступного живого участника; отказ не требует расходования еды.
static func apply_food(actor: Entity, effect: DEF_FoodEffect) -> bool:
	if not GrabService.holder_available(actor) or actor.has_component(C_Death) or effect == null or not is_finite(effect.hunger_relief) or effect.hunger_relief <= 0.0:
		return false

	var state: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	if state == null or not _valid_policy(state.policy) or state.value <= 0.0:
		return false

	state.value = clampf(state.value - effect.hunger_relief, 0.0, state.policy.maximum)
	return true


#endregion

#region Чтение игрока и проверка политики
## Читает состояние местного игрока для производного представления, отдельно от живых связей NPC.
static func player_state() -> C_Hunger:
	if not is_instance_valid(ECS.world):
		return null

	var player: Entity = ECS.world.query.with_all([C_PlayerInputController, C_Hunger]).with_none([C_Death]).execute_one()
	return player.get_component(C_Hunger) as C_Hunger if player != null else null


static func _valid_policy(policy: DEF_HungerPolicy) -> bool:
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
