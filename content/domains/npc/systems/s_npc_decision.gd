extends System
## Owns due native BT updates, role-clock publication and immediate branch cleanup.
class_name S_NpcDecision


#region Scheduling
## Declares the due-step execution order before native decisions.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_NpcTraits], Runs.Before: [S_NpcRoute, S_NpcCombat, S_NpcIntent] }


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
	if entity.get_component(C_NpcDecision) != captured \
			or captured.lifecycle_generation != captured_generation:
		return
	var actor: E_DistrictNpc = entity as E_DistrictNpc
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if not NpcDecisionRules.matches_step(person, captured, cycle) or actor.has_component(C_Death):
		return
	_decide(actor, captured)


func _decide(actor: E_DistrictNpc, decision: C_NpcDecision) -> void:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if (
		decision.intent_owner == C_NpcDecision.Owner.IDLE
		and not (intent.movement_active and not intent.arrived)
	):
		awareness.idle_elapsed += decision.scheduled_delta

	# The exact committed sensor interval advances service clocks before the native leaf runs.
	var captured_generation: int = decision.lifecycle_generation
	_world.emit_event(NpcDecisionReady.EVENT, actor, NpcDecisionReady.new(decision.scheduled_delta))
	if not EntityAvailability.contains(actor, _world) \
			or actor.get_component(C_NpcDecision) != decision \
			or decision.lifecycle_generation != captured_generation:
		decision.scheduled_delta = 0.0
		return

	decision.intent_owner = C_NpcDecision.Owner.NONE
	NpcBrainService.update_tree(actor, decision.scheduled_delta)
	if decision.intent_owner != C_NpcDecision.Owner.SCHEDULE:
		NpcScheduleActionService.cancel_schedule(actor, &"branch_released")
	if actor.enabled:
		if decision.intent_owner != C_NpcDecision.Owner.IDLE:
			NpcCommunityService.cancel_activity(actor)
		if decision.intent_owner in [C_NpcDecision.Owner.EMERGENCY, C_NpcDecision.Owner.COMBAT]:
			NpcDialogueService.end(actor)
			var interruption: NpcRoleInterruptionRequest = NpcRoleInterruptionRequest.new(
				NpcRoleInterruptionRequest.Kind.EMERGENCY
			)
			_world.emit_event(NpcRoleInterruptionRequest.EVENT, actor, interruption)
	else:
		decision.scheduled_delta = 0.0
#endregion
