extends RefCounted
## Читает голод, пороги и паузу роста для отладочного представления.
class_name HungerPresentation

const TIER_NAMES: Array[String] = ["Normal", "Hungry", "Starving"]


## Собирает уровень, активное время, пороги и множители без изменения голода.
static func debug_text(actor: Entity) -> String:
	if not is_instance_valid(actor):
		return ""

	var state: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
	if state == null or state.policy == null:
		return ""

	var tier: C_Hunger.Tier = HungerRules.tier(state)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var active: bool = cycle != null and cycle.phase != C_DayCycle.Phase.NIGHT and GrabService.holder_available(actor) and not actor.has_component(C_Death) and not actor.get_tree().paused
	var target: float = state.policy.hungry_threshold if tier == C_Hunger.Tier.NORMAL else state.policy.starving_threshold
	var seconds: float = maxf(0.0, target - state.value) / state.policy.growth_per_second if state.policy.growth_per_second > 0.0 else INF
	return "ГОЛОД %.1f / %.0f · %s\nРост %s · +%.2f/с · время %.1f с\nПороги %.0f / %.0f · до следующего %.1f с\nСкорость ×%.2f · атака ×%.2f\nЗадача: найдите еду, чтобы снизить голод" % [state.value, state.policy.maximum, TIER_NAMES[tier], "активен" if active else "пауза", state.policy.growth_per_second, state.active_seconds, state.policy.hungry_threshold, state.policy.starving_threshold, seconds, HungerRules.speed_multiplier(state), HungerRules.damage_multiplier(state)]
