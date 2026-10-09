extends System
## Owns perceived trait exposure and observed retreat clocks before native decisions.
class_name S_NpcTraits

#region Scheduling
## Declares the due-step execution order before native decisions.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_NpcPerception], Runs.Before: [S_NpcDecision]}


## Selects live actors with the cadence owner's captured interval.
func query() -> QueryBuilder:
	return q.with_all([C_NpcIdentity, C_NpcAwareness, C_NpcIntent,
		{C_NpcDecision: {"scheduled_delta": {"_gt": 0.0}}}]).with_none([C_Death]).enabled()


## Queues one sampled stage using the exact due-step component identity.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var decision: C_NpcDecision = entity.get_component(C_NpcDecision) as C_NpcDecision
		cmd.add_custom(_advance.bind(weakref(entity), decision, decision.lifecycle_generation))
#endregion

#region Due-step progression
func _advance(entity_reference: WeakRef, captured: C_NpcDecision,
		captured_generation: int) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not EntityAvailability.contains(entity, _world) or not entity.has_component(C_NpcIdentity):
		return
	if entity.get_component(C_NpcDecision) != captured \
			or captured.lifecycle_generation != captured_generation:
		return
	var actor: E_DistrictNpc = entity as E_DistrictNpc
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if not NpcDecisionRules.matches_step(person, captured, cycle) or actor.has_component(C_Death):
		return
	var player: Entity = _world.query.with_all([C_PlayerInputController]).execute_one()
	_advance_traits(actor, person, player, captured.scheduled_delta)


func _advance_traits(actor: E_DistrictNpc, person: NpcRecord, player: Entity, delta: float) -> void:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.hazard_distress = NpcRouteSolver.danger_here(actor)
	awareness.light_distress = false
	_observe_retreat(actor, person, player, awareness, delta)
	for rule: DEF_NpcTrait in person.profile.rules:
		if rule.kind == DEF_NpcTrait.Kind.FIRE_AURA:
			NpcTraitService.ensure_aura(actor, person, rule)
			continue

		var triggered: bool = false
		match rule.kind:
			DEF_NpcTrait.Kind.GAZE_AVERSION:
				triggered = awareness.player_visible and NpcTraitRules.gazing(player, actor, rule)
			DEF_NpcTrait.Kind.LIGHT_AVERSION:
				triggered = NpcLightingService.exposure_at(actor.global_position + Vector3.UP, [actor.get_rid()]) > rule.light_threshold
				awareness.light_distress = triggered
			DEF_NpcTrait.Kind.DARK_PREDATOR:
				triggered = awareness.player_visible and NpcLightingService.exposure_at((player as Node as Node3D).global_position + Vector3.UP, [(player as Node as PhysicsBody3D).get_rid()]) < rule.light_threshold
			DEF_NpcTrait.Kind.STRENGTH_TEST:
				triggered = awareness.player_visible and NpcTraitRules.looks_vulnerable(player, person)
		if not triggered:
			awareness.rule_exposure[rule.kind] = 0.0
			continue

		var exposure: float = awareness.rule_exposure.get(rule.kind, 0.0) + delta
		awareness.rule_exposure[rule.kind] = exposure
		if exposure >= rule.warning_seconds and not awareness.warned_rules.has(rule.kind):
			awareness.warned_rules.append(rule.kind)
			actor.show_message(rule.warning_text + " · " + rule.countermeasure)
			NpcPerceptionService.emit_noise(actor, actor.global_position, person.profile.hearing_range * 0.5)
		if exposure >= rule.warning_seconds + rule.reaction_seconds and not awareness.reacted_rules.has(rule.kind) and awareness.player_visible:
			awareness.reacted_rules.append(rule.kind)
			var cycle: C_DayCycle = DayPhaseQueries.current()
			var incident: StringName = StringName("rule/%s/%d/%d/%d" % [person.npc_id, cycle.day_index, cycle.phase, rule.kind])
			NpcSocialService.react(actor, player, NpcMemory.Kind.OFFENSE, incident)

func _observe_retreat(actor: E_DistrictNpc, person: NpcRecord, player: Entity, awareness: C_NpcAwareness, delta: float) -> void:
	var player_body: RigidBody3D = player as Node as RigidBody3D
	if person.profile.personality != DEF_NpcProfile.Personality.BRAZEN or player_body == null or not awareness.player_visible or CombatQueries.target_for(actor) != player:
		awareness.retreat_elapsed = 0.0
		return

	var outward: Vector3 = player_body.global_position - actor.global_position
	outward.y = 0.0
	if player_body.linear_velocity.dot(outward.normalized()) < person.profile.retreat_speed:
		awareness.retreat_elapsed = 0.0
		return

	awareness.retreat_elapsed += delta
	if awareness.retreat_elapsed < person.profile.retreat_seconds:
		return

	var cycle: C_DayCycle = DayPhaseQueries.current()
	var incident: StringName = StringName("retreat/%s/%d/%d" % [person.npc_id, cycle.day_index, cycle.phase])
	NpcSocialService.react(actor, player, NpcMemory.Kind.SUBMISSION, incident)
#endregion
