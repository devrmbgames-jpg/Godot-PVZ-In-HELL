extends System
## Owns the fair pending-route queue and one planning budget per native physics frame.
class_name S_NpcRoutePlanning

#region Scheduling
## Plans after route progression and before movement/noise downstream consumers.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_NpcRoute], Runs.Before: [S_NpcNoise, S_NpcCombat, S_NpcIntent]}


## Selects the authoritative district queue/budget and current calendar.
func query() -> QueryBuilder:
	return q.with_all([C_District, C_DayCycle])


## Queues budget consumption after the complete route progress batch.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for session: Entity in entities:
		var district: C_District = session.get_component(C_District) as C_District
		cmd.add_custom(_plan_pending.bind(weakref(session), district))
#endregion

#region Fair planning queue
func _plan_pending(session_reference: WeakRef, captured: C_District) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if not EntityAvailability.contains(session, _world) or session.get_component(C_District) != captured:
		return
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	if cycle.phase != C_DayCycle.Phase.NIGHT:
		_process_pending(captured)


func _process_pending(district: C_District) -> void:
	var frame: int = Engine.get_physics_frames()
	if district.route_planning_frame != frame:
		district.route_planning_frame = frame
		district.route_plans_this_frame = 0

	var attempts: int = district.pending_routes.size()
	while attempts > 0 and not district.pending_routes.is_empty() and district.route_plans_this_frame < district.definition.route_plans_per_frame:
		attempts -= 1
		var npc_id: StringName = district.pending_routes.pop_front()
		var person: NpcRecord = DistrictPopulationService.person_for(npc_id)
		var actor: E_DistrictNpc = DistrictPopulationService.body_for(npc_id)
		if person == null or person.death_day != 0 or person.placement != NpcRecord.Placement.STREET or not EntityAvailability.contains(actor, ECS.world):
			continue

		var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
		if route == null or not route.pending:
			continue

		var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
		if not intent.movement_active or intent.move_uses_entity or not intent.navigation_enabled:
			route.pending = false
			route.points.clear()
			route.reachable = true
			continue

		var map: RID = actor.navigation_agent.get_navigation_map()
		if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
			district.pending_routes.append(npc_id)
			continue

		route.goal = intent.move_position
		route.points = NpcRouteSolver.plan(actor, person, actor.global_position, route.goal, map)
		route.navigation_map = map
		route.map_iteration = NavigationServer3D.map_get_iteration_id(map)
		route.point_index = 1 if route.points.size() > 1 else 0
		route.reachable = not route.points.is_empty()
		route.elapsed = 0.0
		route.pending = false
		district.route_plans_this_frame += 1
#endregion
