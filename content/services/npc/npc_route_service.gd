extends RefCounted
## Compares navmesh paths on the authored passage graph by length and effective exposure damage.
class_name NpcRouteService

const ENDPOINT_TOLERANCE: float = 1.0
const GRAPH_CONNECTORS: int = 3

#region Route execution
## Refreshes a derived route without changing final arrival/service semantics.
static func tick(actor: E_DistrictNpc, person: NpcRecord, delta: float) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if not actor.has_component(C_NpcRoute):
		actor.add_component(C_NpcRoute.new())
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	if not intent.movement_active or intent.move_uses_entity or not intent.navigation_enabled:
		route.points.clear()
		route.reachable = true
		route.blocked_seconds = 0.0
		return
	route.elapsed += delta
	var district: C_District = DistrictPopulationService.current()
	if route.goal.distance_to(intent.move_position) > district.definition.waypoint_distance or route.elapsed >= district.definition.route_interval or route.points.is_empty():
		route.elapsed = 0.0
		route.goal = intent.move_position
		var map: RID = actor.navigation_agent.get_navigation_map()
		if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
			return
		route.points = plan(actor, person, actor.global_position, route.goal, map)
		route.point_index = 1 if route.points.size() > 1 else 0
		route.reachable = not route.points.is_empty()
	if route.reachable:
		route.blocked_seconds = 0.0
	else:
		route.blocked_seconds += delta
		if route.blocked_seconds >= district.definition.route_timeout:
			route.blocked_seconds = 0.0
			if CombatService.target_for(actor) != null:
				CombatService.end_combat(actor)
				(actor.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing = true
			var agent: C_CustomerAgent = actor.get_component(C_CustomerAgent) as C_CustomerAgent
			if agent != null:
				var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
				if visit != null:
					NpcServiceRole.finish_appearance(actor, visit)
			else:
				person.phase_complete = true
			NpcIntentService.stop(actor)

## Calculates an actual navmesh route, preferring affordable alternatives.
static func plan(actor: E_DistrictNpc, person: NpcRecord, start: Vector3, goal: Vector3, map: RID) -> PackedVector3Array:
	var district: C_District = DistrictPopulationService.current()
	var iteration: int = NavigationServer3D.map_get_iteration_id(map)
	if district.route_map_iteration != iteration:
		district.route_edges.clear()
		district.route_map_iteration = iteration
	var direct: PackedVector3Array = _nav_path(map, start, goal)
	var direct_damage: float = expected_damage(actor, direct)
	if not direct.is_empty() and direct_damage == 0.0 and person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION) == null:
		return direct
	var best: PackedVector3Array = direct if acceptable(actor, person, direct_damage) else PackedVector3Array()
	var best_cost: float = _cost(actor, person, best) if not best.is_empty() else INF
	var starts: Array[DEF_DistrictPlace] = _nearest(start)
	var ends: Array[DEF_DistrictPlace] = _nearest(goal)
	for entry: DEF_DistrictPlace in starts:
		var connector: PackedVector3Array = _nav_path(map, start, DistrictPopulationService.position_for(entry.key))
		if connector.is_empty() or not acceptable(actor, person, expected_damage(actor, connector)):
			continue
		var distances: Dictionary[StringName, float] = {entry.key: _cost(actor, person, connector)}
		var paths: Dictionary[StringName, PackedVector3Array] = {entry.key: connector}
		var open: Array[StringName] = [entry.key]
		while not open.is_empty():
			open.sort_custom(func(first: StringName, second: StringName) -> bool: return distances[first] < distances[second])
			var key: StringName = open.pop_front()
			var place: DEF_DistrictPlace = district.definition.place_for(key)
			if distances[key] >= best_cost:
				continue
			if ends.has(place):
				var tail: PackedVector3Array = _nav_path(map, DistrictPopulationService.position_for(key), goal)
				var complete: PackedVector3Array = paths[key].duplicate()
				complete.append_array(tail)
				if not tail.is_empty() and acceptable(actor, person, expected_damage(actor, complete)):
					var cost: float = _cost(actor, person, complete)
					if cost < best_cost:
						best = complete
						best_cost = cost
			for neighbour: String in place.neighbours:
				var next_key: StringName = StringName(neighbour)
				var next_place: DEF_DistrictPlace = district.definition.place_for(next_key)
				if next_place == null or next_place.kind != DEF_DistrictPlace.Kind.JUNCTION:
					continue
				var edge_key: String = "%s>%s" % [key, next_key]
				if not district.route_edges.has(edge_key):
					district.route_edges[edge_key] = _nav_path(map, DistrictPopulationService.position_for(key), DistrictPopulationService.position_for(next_key))
				var edge: PackedVector3Array = district.route_edges[edge_key]
				if edge.is_empty():
					continue
				var candidate: PackedVector3Array = paths[key].duplicate()
				candidate.append_array(edge)
				if not acceptable(actor, person, expected_damage(actor, candidate)):
					continue
				var next_cost: float = distances[key] + _cost(actor, person, edge)
				if next_cost < float(distances.get(next_key, INF)):
					distances[next_key] = next_cost
					paths[next_key] = candidate
					if not open.has(next_key):
						open.append(next_key)
	return best
#endregion

#region Shared risk calculation
## Detects real harmful overlap, including a body clearance around the authored sphere.
static func danger_here(actor: E_DistrictNpc) -> bool:
	for effect: Entity in ECS.world.query.with_all([C_Hazard, C_ToxicArea]).execute():
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
		for effect: Entity in ECS.world.query.with_all([C_Hazard, C_ToxicArea]).execute():
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
	if path.is_empty():
		return INF
	var damage: float = 0.0
	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	var speed: float = maxf(0.1, motion.max_speed if motion != null else 1.0)
	for effect: Entity in ECS.world.query.with_all([C_Hazard, C_ToxicArea]).execute():
		var hazard: C_Hazard = effect.get_component(C_Hazard) as C_Hazard
		var profile: DEF_ToxicArea = hazard.definition as DEF_ToxicArea
		var spatial: Node3D = effect as Node as Node3D
		if profile == null or spatial == null or effect.has_component(C_NoDamage):
			continue
		for index: int in range(1, path.size()):
			var duration: float = _inside_length(path[index - 1], path[index], spatial.global_position, profile.radius + (actor as E_DistrictNpc).navigation_agent.radius if actor is E_DistrictNpc else profile.radius) / speed
			damage += DamageResistanceRules.effective(actor, duration * profile.damage_per_tick / profile.tick_seconds, profile.damage_type)
	return damage

## Ordinary travel has a small risk budget; pursuit must preserve the authored HP reserve.
static func acceptable(actor: Entity, person: NpcRecord, damage: float) -> bool:
	if not is_finite(damage):
		return false
	var health: C_Health = actor.get_component(C_Health) as C_Health
	var district: C_District = DistrictPopulationService.current()
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	if awareness != null and awareness.hazard_distress:
		return damage < health.current
	var budget: float = health.current - health.value * person.profile.pursuit_health_reserve if CombatService.target_for(actor) != null else health.value * district.definition.ordinary_route_risk
	return damage <= maxf(0.0, budget)

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

static func _cost(actor: E_DistrictNpc, person: NpcRecord, path: PackedVector3Array) -> float:
	if path.is_empty():
		return INF
	var distance: float = 0.0
	var light_cost: float = 0.0
	var rule: DEF_NpcTrait = person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION)
	for index: int in range(1, path.size()):
		var length: float = path[index - 1].distance_to(path[index])
		distance += length
		if rule != null:
			var exposure: float = NpcLightingService.exposure_at((path[index - 1] + path[index]) * 0.5 + Vector3.UP, [actor.get_rid()])
			light_cost += length * maxf(0.0, exposure - rule.light_threshold) * 10.0
	return distance + expected_damage(actor, path) * DistrictPopulationService.current().definition.danger_penalty + light_cost

static func _nav_path(map: RID, start: Vector3, goal: Vector3) -> PackedVector3Array:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, goal, true)
	if path.is_empty() or path[path.size() - 1].distance_to(goal) > ENDPOINT_TOLERANCE:
		return PackedVector3Array()
	return path

static func _nearest(point: Vector3) -> Array[DEF_DistrictPlace]:
	var places: Array[DEF_DistrictPlace] = []
	for place: DEF_DistrictPlace in DistrictPopulationService.current().definition.places:
		if place.kind == DEF_DistrictPlace.Kind.JUNCTION:
			places.append(place)
	places.sort_custom(func(first: DEF_DistrictPlace, second: DEF_DistrictPlace) -> bool:
		return DistrictPopulationService.position_for(first.key).distance_squared_to(point) < DistrictPopulationService.position_for(second.key).distance_squared_to(point)
	)
	places.resize(mini(GRAPH_CONNECTORS, places.size()))
	return places
#endregion
