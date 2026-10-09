extends System
## Owns post-BT route progression, stall/blocked clocks and lifecycle cleanup.
class_name S_NpcRoute

#region Scheduling
## Declares the due-step execution order before native decisions.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_NpcDecision], Runs.Before: [S_NpcRoutePlanning, S_NpcCombat, S_NpcIntent]}


## Selects live actors with the cadence owner's captured interval.
func query() -> QueryBuilder:
	return q.with_all([C_NpcIdentity, C_NpcAwareness, C_NpcIntent,
		{C_NpcDecision: {"scheduled_delta": {"_gt": 0.0}}}]).with_none([C_Death]).enabled()


## Queues one sampled stage using the exact due-step component identity.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var decision: C_NpcDecision = entity.get_component(C_NpcDecision) as C_NpcDecision
		cmd.add_custom(_advance.bind(weakref(entity), decision))
#endregion

#region Due-step progression
func _advance(entity_reference: WeakRef, captured: C_NpcDecision) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not EntityAvailability.contains(entity, _world) or not entity.has_component(C_NpcIdentity):
		return
	if entity.get_component(C_NpcDecision) != captured:
		return
	var actor: E_DistrictNpc = entity as E_DistrictNpc
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if not NpcDecisionRules.matches_step(person, captured, cycle) or actor.has_component(C_Death):
		return
	_progress_route(actor, person, captured.scheduled_delta)
	captured.scheduled_delta = 0.0


func _progress_route(actor: E_DistrictNpc, person: NpcRecord, delta: float) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if not actor.has_component(C_NpcRoute):
		actor.add_component(C_NpcRoute.new())
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute

	# Inactive/direct-follow intent releases derived navigation without inventing a failed trip.
	if not intent.movement_active or intent.move_uses_entity or not intent.navigation_enabled:
		route.pending = false
		route.map_iteration = -1
		route.points.clear()
		route.reachable = true
		route.blocked_seconds = 0.0
		route.progress_initialized = false
		route.stalled_seconds = 0.0
		return

	route.elapsed += delta
	var district: C_District = NpcPopulationQueries.current()
	var new_goal: bool = route.goal.distance_to(intent.move_position) > district.definition.waypoint_distance
	if new_goal:
		route.progress_initialized = false
		route.points.clear()
		route.reachable = false
	var needs_plan: bool = new_goal or route.map_iteration < 0
	if route.elapsed >= district.definition.route_interval:
		route.elapsed = 0.0
		var map: RID = actor.navigation_agent.get_navigation_map()
		var iteration: int = NavigationServer3D.map_get_iteration_id(map) if map.is_valid() else 0
		needs_plan = needs_plan or route.points.is_empty() or route.navigation_map != map or route.map_iteration != iteration
		if not route.points.is_empty():
			var remaining: PackedVector3Array = PackedVector3Array([actor.global_position])
			remaining.append_array(route.points.slice(route.point_index))
			if not NpcRouteSolver.acceptable(actor, person, NpcRouteSolver.expected_damage(actor, remaining)):
				route.points.clear()
				needs_plan = true
	if needs_plan:
		route.goal = intent.move_position
		if route.points.is_empty():
			route.reachable = false
		route.pending = true
		if not district.pending_routes.has(person.npc_id):
			district.pending_routes.append(person.npc_id)

	# Physical movement is sampled from the body; this owner only updates route clocks.
	var physical_position: Vector3 = actor.global_position
	physical_position.y = 0.0
	var final_position: Vector3 = intent.move_position
	final_position.y = 0.0
	if not route.progress_initialized or physical_position.distance_to(route.progress_position) >= district.definition.route_progress_distance or physical_position.distance_to(final_position) <= intent.arrival_distance:
		route.progress_initialized = true
		route.progress_position = physical_position
		route.stalled_seconds = 0.0
	else:
		route.stalled_seconds += delta

	if route.reachable:
		route.blocked_seconds = 0.0
	else:
		route.blocked_seconds += delta

	if maxf(route.blocked_seconds, route.stalled_seconds) >= district.definition.route_timeout:
		_abandon(actor, person, route)


func _abandon(actor: E_DistrictNpc, person: NpcRecord, route: C_NpcRoute) -> void:
	route.pending = false
	route.blocked_seconds = 0.0
	route.stalled_seconds = 0.0
	route.progress_initialized = false
	NpcCommunityService.cancel_activity(actor)
	NpcDialogueService.end(actor)
	if CombatQueries.target_for(actor) != null:
		CombatService.end_combat(actor)
		(actor.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing = true

	var interruption: NpcRoleInterruptionRequest = NpcRoleInterruptionRequest.new(NpcRoleInterruptionRequest.Kind.ROUTE_BLOCKED)
	_world.emit_event(NpcRoleInterruptionRequest.EVENT, actor, interruption)
	if not interruption.handled:
		var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
		var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(person.planned_day, person.planned_phase as C_DayCycle.Phase)
		# Недостижимое занятие можно пропустить; уход через проход или домой требует реального прибытия.
		if decision != null and decision.intent_owner == C_NpcDecision.Owner.SCHEDULE and person.profile.resident and location == DEF_NpcSchedule.Location.STREET:
			DistrictPopulationService.request_phase_completion(actor, NpcRecord.Placement.STREET)
		route.map_iteration = -1
		route.points.clear()
	NpcIntentService.stop(actor)
#endregion
