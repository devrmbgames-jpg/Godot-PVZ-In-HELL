extends System
## Owns sight/search/hearing progression for the captured due batch.
class_name S_NpcPerception

#region Scheduling
## Declares the due-step execution order before native decisions.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_NpcFootsteps], Runs.Before: [S_NpcTraits]}


## Selects live actors with the cadence owner's captured interval.
func query() -> QueryBuilder:
	return q.with_all([C_NpcIdentity, C_NpcAwareness, C_NpcIntent,
		{C_NpcDecision: {"scheduled_delta": {"_gt": 0.0}}}]).with_none([C_Death]).enabled()


## Queues one sampled stage using the exact due-step component identity.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var decision: C_NpcDecision = entity.get_component(C_NpcDecision) as C_NpcDecision
		cmd.add_custom(_advance.bind(entity, decision))
#endregion

#region Due-step progression
func _advance(entity: Entity, captured: C_NpcDecision) -> void:
	if not EntityAvailability.contains(entity, _world) or not entity.has_component(C_NpcIdentity):
		return
	if entity.get_component(C_NpcDecision) != captured:
		return
	var actor: E_DistrictNpc = entity as E_DistrictNpc
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id)
	var cycle: C_DayCycle = DayPhaseService.current()
	if not NpcDecisionRules.matches_step(person, captured, cycle) or actor.has_component(C_Death):
		return
	var player: Entity = _world.query.with_all([C_PlayerInputController]).execute_one()
	_sense(actor, person, player, captured.scheduled_delta)


func _sense(actor: E_DistrictNpc, person: NpcRecord, player: Entity, delta: float) -> void:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.player_visible = player != null and NpcPerceptionService.can_see(actor, player, person.profile)
	if not awareness.player_visible and NpcDialogueService.participant(actor) == null:
		NpcIntentService.look_along_movement(actor)
	var opponent: Entity = CombatService.target_for(actor)
	awareness.target_visible = opponent != null and NpcPerceptionService.can_see(actor, opponent, person.profile)
	if awareness.target_visible:
		awareness.last_seen_position = (opponent as Node as Node3D).global_position
		awareness.has_last_seen = true
		awareness.search_elapsed = 0.0
		awareness.search_index = 0
	elif opponent != null:
		awareness.search_elapsed += delta
	awareness.heard_remaining = maxf(0.0, awareness.heard_remaining - delta)

	var district: C_District = DistrictPopulationService.current()
	for noise: NpcNoise in district.noises:
		if noise.sequence > awareness.last_noise_sequence:
			awareness.last_noise_sequence = noise.sequence
			NpcPerceptionService.hear(actor, person.profile, noise)
#endregion
