extends System
## Owns hunger growth and active seconds, preserving phase/alive/paused policy gates.
class_name S_Hunger

#region Scheduling
## Calendar commits precede growth; common attacks read the new multiplier afterwards.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_DayPhase], Runs.Before: [S_PlayerMelee, S_NpcCombat]}


## Selects live participating hunger owners; dormant/dead actors consume no active time.
func query() -> QueryBuilder:
	return q.with_all([C_Hunger]).with_none([C_Death]).enabled()


## Commits only scalar growth; no structural command or hidden Service clock is required.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT or not is_finite(delta) or delta <= 0.0:
		return
	if get_tree().paused:
		return

	for actor: Entity in entities:
		var state: C_Hunger = actor.get_component(C_Hunger) as C_Hunger
		if not HungerRules.valid_policy(state.policy) or not GrabQueries.holder_available(actor):
			continue

		state.value = clampf(state.value + delta * state.policy.growth_per_second, 0.0, state.policy.maximum)
		state.active_seconds += delta
#endregion
