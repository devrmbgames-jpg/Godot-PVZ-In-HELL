extends System
## Owns sight/search/hearing progression for the captured due batch.
class_name S_NpcPerception


#region Scheduling
## Declares the due-step execution order before native decisions.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_NpcFootsteps], Runs.Before: [S_NpcTraits] }


## Selects live actors with the cadence owner's captured interval.
func query() -> QueryBuilder:
	return q.with_all([
		C_NpcIdentity,
		C_NpcAwareness,
		C_NpcIntent,
		{ C_NpcDecision: { "scheduled_delta": { "_gt": 0.0 } } },
	]).with_none([C_Death]).enabled()


## Queues one sampled stage using the exact due-step component identity.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var decision: C_NpcDecision = entity.get_component(C_NpcDecision) as C_NpcDecision
		cmd.add_custom(_advance.bind(weakref(entity), decision, decision.lifecycle_generation))
#endregion


#region Due-step progression
func _advance(entity_reference: WeakRef, captured: C_NpcDecision, captured_generation: int) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not EntityAvailability.contains(entity, _world) or not entity.has_component(C_NpcIdentity):
		return
	if (
		entity.get_component(C_NpcDecision) != captured
		or captured.lifecycle_generation != captured_generation
	):
		return
	var actor: E_DistrictNpc = entity as E_DistrictNpc
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if not NpcDecisionRules.matches_step(person, captured, cycle) or actor.has_component(C_Death):
		return
	var player: Entity = _world.query.with_all([C_PlayerInputController]).execute_one()
	_sense(actor, person, player, captured.scheduled_delta)


func _sense(actor: E_DistrictNpc, person: NpcRecord, player: Entity, delta: float) -> void:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	var generation: int = decision.lifecycle_generation
	var actor_reference: WeakRef = weakref(actor)
	var player_reference: WeakRef = weakref(player) if player != null else null
	_sample_blood(actor, person)
	# UNCLEAN observation publishes a social fact: subscribers may retire/reset this receiver.
	actor = actor_reference.get_ref() as E_DistrictNpc
	if (
		not EntityAvailability.contains(actor, _world)
		or actor.has_component(C_Death) or actor.get_component(C_NpcDecision) != decision
		or actor.get_component(C_NpcAwareness) != awareness
		or decision.lifecycle_generation != generation
	):
		return
	player = player_reference.get_ref() as Entity if player_reference != null else null
	if not EntityAvailability.contains(player, _world):
		player = null
	awareness.player_visible = (
		player != null and NpcPerceptionService.can_see(actor, player, person)
	)
	if not awareness.player_visible and NpcDialogueService.participant(actor) == null:
		NpcIntentService.look_along_movement(actor)
	var opponent: Entity = CombatQueries.target_for(actor)
	awareness.target_visible = (
		opponent != null and NpcPerceptionService.can_see(actor, opponent, person)
	)
	if awareness.target_visible:
		awareness.last_seen_position = (opponent as Node as Node3D).global_position
		awareness.has_last_seen = true
		awareness.search_elapsed = 0.0
		awareness.search_index = 0
	elif opponent != null:
		awareness.search_elapsed += delta
	awareness.heard_remaining = maxf(0.0, awareness.heard_remaining - delta)

	var district: C_District = NpcPopulationQueries.current()
	for noise: NpcNoise in district.noises:
		if noise.sequence > awareness.last_noise_sequence:
			awareness.last_noise_sequence = noise.sequence
			NpcPerceptionService.hear(actor, person.profile, noise)


## Cadenced selection shares normal LOS/light/FOV and remembers only a native live binding.
func _sample_blood(actor: E_DistrictNpc, person: NpcRecord) -> void:
	if (
		not NpcBloodQueries.has_trait(actor, C_ReceiverTraits.Trait.VAMPIRE)
		and not NpcBloodQueries.has_trait(actor, C_ReceiverTraits.Trait.UNCLEAN)
	):
		NpcBloodService.release(actor)
		return
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	var previous: E_BloodArea = NpcBloodQueries.zone_for(actor)
	if previous != null and NpcBloodQueries.inside(actor, previous):
		NpcBloodService.observe(actor, person, previous)
		return
	if previous != null and NpcBloodQueries.approach_failed(actor, previous):
		if not awareness.rejected_blood_ids.has(previous.id):
			awareness.rejected_blood_ids.append(previous.id)
	var live_ids: Array[String] = []
	var nearest: E_BloodArea = null
	var distance: float = INF
	var zones: QueryBuilder = _world.query.with_all([C_BloodArea, C_Hazard, C_HazardLifetime])
	for entity: Entity in zones.enabled().execute():
		if not NpcBloodQueries.valid_zone(entity):
			continue
		live_ids.append(entity.id)
		var zone: E_BloodArea = entity as E_BloodArea
		var candidate_distance: float = actor.global_position.distance_squared_to(
			zone.global_position
		)
		if (
			awareness.rejected_blood_ids.has(zone.id) or candidate_distance >= distance
			or not NpcPerceptionService.can_see_point(actor, zone.global_position, person, zone)
		):
			continue
		nearest = zone
		distance = candidate_distance
	for rejected: String in awareness.rejected_blood_ids.duplicate():
		if not live_ids.has(rejected):
			awareness.rejected_blood_ids.erase(rejected)
	if nearest != null:
		NpcBloodService.observe(actor, person, nearest)
	else:
		NpcBloodService.release(actor)
#endregion
