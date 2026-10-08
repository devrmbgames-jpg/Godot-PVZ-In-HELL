extends RefCounted
## Explicit food/value commands and optional local-player lookup; calculations belong to HungerRules.
class_name HungerService

#region Рост и питание
## Явно задаёт допустимый уровень через ту же проверку доступности и границ, что у еды.
static func set_value(actor: Entity, value: float) -> bool:
	if not GrabQueries.holder_available(actor) or actor.has_component(C_Death):
		return false

	var state: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	if state == null or not HungerRules.valid_policy(state.policy) or not is_finite(value) or value < 0.0 or value > state.policy.maximum:
		return false

	state.value = value
	return true


## Уменьшает положительный голод доступного живого участника; отказ не требует расходования еды.
static func apply_food(actor: Entity, effect: DEF_FoodEffect) -> bool:
	if not GrabQueries.holder_available(actor) or actor.has_component(C_Death) or effect == null or not is_finite(effect.hunger_relief) or effect.hunger_relief <= 0.0:
		return false

	var state: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	if state == null or not HungerRules.valid_policy(state.policy) or state.value <= 0.0:
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


#endregion
