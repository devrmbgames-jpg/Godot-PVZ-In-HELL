extends RefCounted
## Compares navmesh paths on the authored passage graph by length and effective exposure damage.
class_name NpcRouteService

const ENDPOINT_TOLERANCE: float = 1.0
const GRAPH_CONNECTORS: int = 3

static var _query_world: World = null
static var _hazard_query: QueryBuilder = null

#region Route execution
## Refreshes a derived route without changing final arrival/service semantics.
static func tick(actor: E_DistrictNpc, person: NpcRecord, delta: float) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if not actor.has_component(C_NpcRoute):
		actor.add_component(C_NpcRoute.new())
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	if not intent.movement_active or intent.move_uses_entity or not intent.navigation_enabled:
		route.pending = false
		route.points.clear()
		route.reachable = true
		route.blocked_seconds = 0.0
		route.progress_initialized = false
		route.stalled_seconds = 0.0
		return
	route.elapsed += delta
	var district: C_District = DistrictPopulationService.current()
	var new_goal: bool = route.goal.distance_to(intent.move_position) > district.definition.waypoint_distance
	if new_goal:
		route.progress_initialized = false
		route.points.clear()
		route.reachable = false
	if new_goal or route.elapsed >= district.definition.route_interval or route.points.is_empty():
		route.goal = intent.move_position
		if route.points.is_empty():
			route.reachable = false
		route.pending = true
		if not district.pending_routes.has(person.npc_id):
			district.pending_routes.append(person.npc_id)

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

## Executes a bounded fair batch, revalidating live intent before committing each route.
static func process_pending(district: C_District) -> void:
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
		route.points = plan(actor, person, actor.global_position, route.goal, map)
		route.point_index = 1 if route.points.size() > 1 else 0
		route.reachable = not route.points.is_empty()
		route.elapsed = 0.0
		route.pending = false
		district.route_plans_this_frame += 1

static func _abandon(actor: E_DistrictNpc, person: NpcRecord, route: C_NpcRoute) -> void:
	route.pending = false
	route.blocked_seconds = 0.0
	route.stalled_seconds = 0.0
	route.progress_initialized = false
	NpcCommunityService.cancel_activity(actor)
	NpcDialogueService.end(actor)
	if CombatService.target_for(actor) != null:
		CombatService.end_combat(actor)
		(actor.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing = true

	var agent: C_CustomerAgent = actor.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent != null:
		var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
		if NpcHomeDeliveryService.meeting_for(actor) != null:
			NpcServiceRole.suspend(actor)
		elif visit != null:
			NpcServiceRole.finish_appearance(actor, visit)
	else:
		person.phase_complete = true
	NpcIntentService.stop(actor)

## Calculates an actual navmesh route, reusing each segment evaluation within this plan.
static func plan(actor: E_DistrictNpc, person: NpcRecord, start: Vector3, goal: Vector3, map: RID) -> PackedVector3Array:
	var context: NpcRouteContext = _context(actor, person)
	var district: C_District = context.district
	var iteration: int = NavigationServer3D.map_get_iteration_id(map)
	if district.route_map_iteration != iteration:
		district.route_edges.clear()
		district.route_map_iteration = iteration

	var direct: PackedVector3Array = _nav_path(map, start, goal)
	var direct_result: NpcRouteContext.Evaluation = _evaluate(context, direct)
	if not direct.is_empty() and direct_result.damage == 0.0 and context.light_rule == null:
		return direct

	var best: PackedVector3Array = direct if _affordable(context, direct_result.damage) else PackedVector3Array()
	var best_cost: float = direct_result.cost if not best.is_empty() else INF
	var local_path: PackedVector3Array = _local_detour(context, start, goal, map)
	if not local_path.is_empty():
		var local_result: NpcRouteContext.Evaluation = _evaluate(context, local_path)
		if local_result.cost < best_cost:
			best = local_path
			best_cost = local_result.cost

	var starts: Array[DEF_DistrictPlace] = _nearest(context, start)
	var ends: Array[DEF_DistrictPlace] = _nearest(context, goal)
	for entry: DEF_DistrictPlace in starts:
		var connector: PackedVector3Array = _nav_path(map, start, context.positions[entry.key])
		var connector_result: NpcRouteContext.Evaluation = _evaluate(context, connector)
		if connector.is_empty() or not _affordable(context, connector_result.damage):
			continue

		var distances: Dictionary[StringName, float] = {entry.key: connector_result.cost}
		var damages: Dictionary[StringName, float] = {entry.key: connector_result.damage}
		var paths: Dictionary[StringName, PackedVector3Array] = {entry.key: connector}
		var open: Array[StringName] = [entry.key]
		while not open.is_empty():
			open.sort_custom(func(first: StringName, second: StringName) -> bool: return distances[first] < distances[second])
			var key: StringName = open.pop_front()
			var place: DEF_DistrictPlace = district.definition.place_for(key)
			if distances[key] >= best_cost:
				continue

			if ends.has(place):
				var tail: PackedVector3Array = _nav_path(map, context.positions[key], goal)
				var tail_result: NpcRouteContext.Evaluation = _evaluate(context, tail)
				var total_damage: float = damages[key] + tail_result.damage
				var total_cost: float = distances[key] + tail_result.cost
				if not tail.is_empty() and _affordable(context, total_damage) and total_cost < best_cost:
					best = paths[key].duplicate()
					best.append_array(tail)
					best_cost = total_cost

			for neighbour: String in place.neighbours:
				var next_key: StringName = StringName(neighbour)
				var next_place: DEF_DistrictPlace = district.definition.place_for(next_key)
				if next_place == null or next_place.kind != DEF_DistrictPlace.Kind.JUNCTION:
					continue

				var edge_key: String = "%s>%s" % [key, next_key]
				if not district.route_edges.has(edge_key):
					district.route_edges[edge_key] = _nav_path(map, context.positions[key], context.positions[next_key])
				var edge: PackedVector3Array = district.route_edges[edge_key]
				if edge.is_empty():
					continue
				if not context.edge_evaluations.has(edge_key):
					context.edge_evaluations[edge_key] = _evaluate(context, edge)
				var result: NpcRouteContext.Evaluation = context.edge_evaluations[edge_key]
				var next_damage: float = damages[key] + result.damage
				var next_cost: float = distances[key] + result.cost
				if not _affordable(context, next_damage) or next_cost >= float(distances.get(next_key, INF)):
					continue

				var candidate: PackedVector3Array = paths[key].duplicate()
				candidate.append_array(edge)
				distances[next_key] = next_cost
				damages[next_key] = next_damage
				paths[next_key] = candidate
				if not open.has(next_key):
					open.append(next_key)
	return best

static func _local_detour(context: NpcRouteContext, start: Vector3, goal: Vector3, map: RID) -> PackedVector3Array:
	var forward: Vector3 = goal - start
	forward.y = 0.0
	if forward.is_zero_approx():
		return PackedVector3Array()

	forward = forward.normalized()
	var side: Vector3 = forward.cross(Vector3.UP)
	var best: PackedVector3Array = PackedVector3Array()
	var best_cost: float = INF
	for hazard: NpcRouteContext.Hazard in context.hazards:
		var center: Vector3 = hazard.center
		center.y = start.y
		var extent: float = hazard.radius + context.district.definition.local_detour_margin
		if _inside_length(start, goal, center, extent) <= 0.0:
			continue

		for sign_value: float in [-1.0, 1.0]:
			var before: Vector3 = center - forward * extent + side * extent * sign_value
			var after: Vector3 = center + forward * extent + side * extent * sign_value
			var first: PackedVector3Array = _nav_path(map, start, before)
			var middle: PackedVector3Array = _nav_path(map, before, after)
			var last: PackedVector3Array = _nav_path(map, after, goal)
			if first.is_empty() or middle.is_empty() or last.is_empty():
				continue

			first.append_array(middle)
			first.append_array(last)
			var result: NpcRouteContext.Evaluation = _evaluate(context, first)
			if _affordable(context, result.damage) and result.cost < best_cost:
				best = first
				best_cost = result.cost
	return best
#endregion

#region Shared risk calculation
## Detects real harmful overlap, including a body clearance around the authored sphere.
static func danger_here(actor: E_DistrictNpc) -> bool:
	for effect: Entity in _hazard_entities():
		var profile: DEF_ToxicArea = (effect.get_component(C_Hazard) as C_Hazard).definition as DEF_ToxicArea
		var spatial: Node3D = effect as Node as Node3D
		if profile != null and spatial != null and not effect.has_component(C_NoDamage) and DamageResistanceRules.effective(actor, profile.damage_per_tick, profile.damage_type) > 0.0 and spatial.global_position.distance_to(actor.global_position + Vector3.UP * NpcPerceptionService.TORSO_HEIGHT) < profile.radius + actor.navigation_agent.radius:
			return true
	return false

## Chooses the closest actual refuge outside damaging volumes; the route planner still validates travel.
static func refuge(actor: E_DistrictNpc) -> Vector3:
	var best: Vector3 = actor.global_position
	var closest: float = INF
	for place: DEF_DistrictPlace in DistrictPopulationService.current().definition.places:
		var point: Vector3 = DistrictPopulationService.position_for(place.key)
		var danger: bool = false
		for effect: Entity in _hazard_entities():
			var profile: DEF_ToxicArea = (effect.get_component(C_Hazard) as C_Hazard).definition as DEF_ToxicArea
			var spatial: Node3D = effect as Node as Node3D
			if profile != null and spatial != null and not effect.has_component(C_NoDamage) and DamageResistanceRules.effective(actor, profile.damage_per_tick, profile.damage_type) > 0.0 and point.distance_to(spatial.global_position) < profile.radius + actor.navigation_agent.radius:
				danger = true
		var distance: float = actor.global_position.distance_squared_to(point)
		if not danger and distance < closest:
			best = point
			closest = distance
	return best

## Expected periodic exposure uses the same type multiplier as O_Damage.
static func expected_damage(actor: Entity, path: PackedVector3Array) -> float:
	return _damage(path, _hazards(actor), _speed(actor))

## Ordinary travel has a small risk budget; pursuit must preserve the authored HP reserve.
static func acceptable(actor: Entity, person: NpcRecord, damage: float) -> bool:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	if awareness != null and awareness.hazard_distress:
		return is_finite(damage) and damage < (actor.get_component(C_Health) as C_Health).current
	return is_finite(damage) and damage <= _risk_budget(actor, person)

static func _risk_budget(actor: Entity, person: NpcRecord) -> float:
	var health: C_Health = actor.get_component(C_Health) as C_Health
	var district: C_District = DistrictPopulationService.current()
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	if awareness != null and awareness.hazard_distress:
		return health.current
	var budget: float = health.current - health.value * person.profile.pursuit_health_reserve if CombatService.target_for(actor) != null else health.value * district.definition.ordinary_route_risk
	return maxf(0.0, budget)

static func _speed(actor: Entity) -> float:
	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	return maxf(0.1, CharacterMotionSolver.effective_speed(motion, actor.get_component(C_CarryLoad) as C_CarryLoad, actor.get_component(C_Strength) as C_Strength, actor.get_component(C_Hunger) as C_Hunger) if motion != null else 1.0)

static func _hazard_entities() -> Array:
	if not is_instance_valid(ECS.world):
		return []
	if _query_world != ECS.world or not is_instance_valid(_query_world):
		_query_world = ECS.world
		_hazard_query = QueryBuilder.new(_query_world).with_all([C_Hazard, C_ToxicArea])
	return _hazard_query.execute()

static func _hazards(actor: Entity) -> Array[NpcRouteContext.Hazard]:
	var result: Array[NpcRouteContext.Hazard] = []
	for effect: Entity in _hazard_entities():
		var profile: DEF_ToxicArea = (effect.get_component(C_Hazard) as C_Hazard).definition as DEF_ToxicArea
		var spatial: Node3D = effect as Node as Node3D
		if profile == null or spatial == null or effect.has_component(C_NoDamage):
			continue
		var rate: float = DamageResistanceRules.effective(actor, profile.damage_per_tick / profile.tick_seconds, profile.damage_type)
		if rate <= 0.0:
			continue

		var hazard: NpcRouteContext.Hazard = NpcRouteContext.Hazard.new()
		hazard.center = spatial.global_position
		hazard.radius = profile.radius + ((actor as E_DistrictNpc).navigation_agent.radius if actor is E_DistrictNpc else 0.0)
		hazard.damage_rate = rate
		result.append(hazard)
	return result

static func _damage(path: PackedVector3Array, hazards: Array[NpcRouteContext.Hazard], speed: float) -> float:
	if path.is_empty():
		return INF
	var damage: float = 0.0
	for hazard: NpcRouteContext.Hazard in hazards:
		for index: int in range(1, path.size()):
			damage += _inside_length(path[index - 1], path[index], hazard.center, hazard.radius) / speed * hazard.damage_rate
	return damage

static func _inside_length(start: Vector3, end: Vector3, center: Vector3, radius: float) -> float:
	var direction: Vector3 = end - start
	direction.y = 0.0
	var offset: Vector3 = start - center
	offset.y = 0.0
	var length: float = direction.length()
	if length < 0.001:
		return 0.0
	var projection: float = -offset.dot(direction / length)
	var perpendicular: float = offset.length_squared() - projection * projection
	if perpendicular >= radius * radius:
		return 0.0
	var half: float = sqrt(maxf(0.0, radius * radius - perpendicular))
	return maxf(0.0, minf(length, projection + half) - maxf(0.0, projection - half))

static func _context(actor: E_DistrictNpc, person: NpcRecord) -> NpcRouteContext:
	var context: NpcRouteContext = NpcRouteContext.new()
	context.district = DistrictPopulationService.current()
	context.lighting = NpcLightingService.context_for(context.district)
	context.light_rule = person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION)
	context.ignored_bodies = [actor.get_rid()]
	context.hazards = _hazards(actor)
	context.speed = _speed(actor)
	context.risk_budget = _risk_budget(actor, person)
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	context.requires_health_after_escape = awareness != null and awareness.hazard_distress
	for index: int in context.lighting.places.size():
		var place: DEF_DistrictPlace = context.lighting.places[index]
		context.positions[place.key] = context.lighting.positions[index]
		if place.kind == DEF_DistrictPlace.Kind.JUNCTION:
			context.junctions.append(place)
	return context

static func _affordable(context: NpcRouteContext, damage: float) -> bool:
	return is_finite(damage) and (damage < context.risk_budget if context.requires_health_after_escape else damage <= context.risk_budget)

static func _evaluate(context: NpcRouteContext, path: PackedVector3Array) -> NpcRouteContext.Evaluation:
	var result: NpcRouteContext.Evaluation = NpcRouteContext.Evaluation.new()
	if path.is_empty():
		return result

	var distance: float = 0.0
	var light_cost: float = 0.0
	for index: int in range(1, path.size()):
		var length: float = path[index - 1].distance_to(path[index])
		distance += length
		if context.light_rule != null and length > 0.0:
			var sample: Vector3 = (path[index - 1] + path[index]) * 0.5 + Vector3.UP
			if not context.light_samples.has(sample):
				context.light_samples[sample] = NpcLightingService.exposure_at(sample, context.ignored_bodies, context.lighting)
			var exposure: float = context.light_samples[sample]
			light_cost += length * maxf(0.0, exposure - context.light_rule.light_threshold) * context.district.definition.light_route_penalty

	result.damage = _damage(path, context.hazards, context.speed)
	result.cost = distance + result.damage * context.district.definition.danger_penalty + light_cost
	return result

static func _nav_path(map: RID, start: Vector3, goal: Vector3) -> PackedVector3Array:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, goal, true)
	if path.is_empty() or path[path.size() - 1].distance_to(goal) > ENDPOINT_TOLERANCE:
		return PackedVector3Array()
	return path

static func _nearest(context: NpcRouteContext, point: Vector3) -> Array[DEF_DistrictPlace]:
	var places: Array[DEF_DistrictPlace] = context.junctions.duplicate()
	places.sort_custom(func(first: DEF_DistrictPlace, second: DEF_DistrictPlace) -> bool:
		return context.positions[first.key].distance_squared_to(point) < context.positions[second.key].distance_squared_to(point)
	)
	places.resize(mini(GRAPH_CONNECTORS, places.size()))
	return places
#endregion
