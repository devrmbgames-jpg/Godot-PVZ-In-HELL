extends System
## Owns due native BT updates, role-clock publication and immediate branch cleanup.
class_name S_NpcDecision

#region Scheduling
## Declares the due-step execution order before native decisions.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_NpcTraits], Runs.Before: [S_NpcNoise, S_NpcCombat, S_NpcIntent]}


## Selects live actors with the cadence owner's captured interval.
func query() -> QueryBuilder:
	return q.with_all([C_NpcIdentity, C_NpcAwareness, C_NpcIntent,
		{C_NpcDecision: {"scheduled_delta": {"_gt": 0.0}}}]).with_none([C_Death]).enabled()


## Queues one sampled stage using the exact due-step component identity.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var decision: C_NpcDecision = entity.get_component(C_NpcDecision) as C_NpcDecision
		cmd.add_custom(_advance.bind(entity, decision))
	cmd.add_custom(_flush_routes)
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
	_decide(actor, person, captured)


func _decide(actor: E_DistrictNpc, person: NpcRecord, decision: C_NpcDecision) -> void:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if decision.intent_owner == C_NpcDecision.Owner.IDLE and not (intent.movement_active and not intent.arrived):
		awareness.idle_elapsed += decision.scheduled_delta

	# The exact committed sensor interval advances service clocks before the native leaf runs.
	_world.emit_event(NpcDecisionReady.EVENT, actor, NpcDecisionReady.new(decision.scheduled_delta))
	if not EntityAvailability.contains(actor, _world) or actor.get_component(C_NpcDecision) != decision:
		decision.scheduled_delta = 0.0
		return

	decision.intent_owner = C_NpcDecision.Owner.NONE
	NpcBrainService.update_tree(actor, decision.scheduled_delta)
	if actor.enabled:
		if decision.intent_owner != C_NpcDecision.Owner.IDLE:
			NpcCommunityService.cancel_activity(actor)
		if decision.intent_owner in [C_NpcDecision.Owner.EMERGENCY, C_NpcDecision.Owner.COMBAT]:
			NpcDialogueService.end(actor)
			NpcServiceRole.suspend(actor)
		# Route cadence/budget migration is the following dependency task 16.
		NpcRouteService.tick(actor, person, decision.scheduled_delta)
	decision.update_elapsed = 0.0
	decision.scheduled_delta = 0.0
#endregion

#region Route queue boundary
func _flush_routes() -> void:
	var district: C_District = DistrictPopulationService.current()
	if district != null and DayPhaseService.current().phase != C_DayCycle.Phase.NIGHT:
		NpcRouteService.process_pending(district)
#endregion
