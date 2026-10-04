extends RefCounted
## Следует авторскому теневому проходу или нативному пути с ограничением работы и проверкой опасностей.
class_name NpcRouteService

const ENDPOINT_TOLERANCE: float = 1.0

static var _query_world: World = null
static var _hazard_query: QueryBuilder = null

#region Выполнение маршрута
## Обновляет производный маршрут, сохраняя правила прибытия и обслуживания.
static func tick(actor: E_DistrictNpc, person: NpcRecord, delta: float) -> void:
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if not actor.has_component(C_NpcRoute):
		actor.add_component(C_NpcRoute.new())
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
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
	var district: C_District = DistrictPopulationService.current()
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
			if not acceptable(actor, person, expected_damage(actor, remaining)):
				route.points.clear()
				needs_plan = true
	if needs_plan:
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

## Выполняет ограниченную справедливую очередь планирования, перепроверяя текущее намерение.
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
		route.navigation_map = map
		route.map_iteration = NavigationServer3D.map_get_iteration_id(map)
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
			NpcServiceRole.defer_visit(actor, visit, "Путь к ПВЗ недоступен")
	else:
		var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
		var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(person.planned_day, person.planned_phase as C_DayCycle.Phase)
		# Недостижимое занятие можно пропустить; уход через проход или домой требует реального прибытия.
		if decision != null and decision.intent_owner == C_NpcDecision.Owner.SCHEDULE and person.profile.resident and location == DEF_NpcSchedule.Location.STREET:
			person.phase_complete = true
		route.map_iteration = -1
		route.points.clear()
	NpcIntentService.stop(actor)

## Строит один путь по авторскому теневому проходу или обычной navmesh.
static func plan(actor: E_DistrictNpc, person: NpcRecord, start: Vector3, goal: Vector3, map: RID) -> PackedVector3Array:
	var context: NpcRouteContext = _context(actor)
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	var escape: bool = awareness != null and awareness.hazard_distress
	var light_sensitive: bool = person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION) != null
	var path: PackedVector3Array = _shade_path(start, goal, map) if light_sensitive and not escape else _nav_path(map, start, goal)
	var damage: float = _damage(path, context.hazards, context.speed)
	if damage == 0.0:
		return path
	# Уже внутри опасности: прямой выход сокращает воздействие; обход вокруг сферы только задержит отход.
	if escape:
		return path if acceptable(actor, person, damage) else PackedVector3Array()

	# Проверить один локальный обход; ждать, если он и исходный путь опасны.
	var bypass: PackedVector3Array = _local_detour(context, path, map)
	if not bypass.is_empty() and acceptable(actor, person, _damage(bypass, context.hazards, context.speed)):
		return bypass
	return path if acceptable(actor, person, damage) else PackedVector3Array()

static func _shade_path(start: Vector3, goal: Vector3, map: RID) -> PackedVector3Array:
	var definition: DEF_District = DistrictPopulationService.current().definition
	if definition.shade_route.is_empty():
		return _nav_path(map, start, goal)

	var passage: PackedVector3Array = PackedVector3Array()
	for key: String in definition.shade_route:
		if definition.place_for(StringName(key)) == null:
			return PackedVector3Array()

		passage.append(DistrictPopulationService.position_for(StringName(key)))

	# Выбрать вход и выход среди авторских точек без поиска альтернативных маршрутов.
	var entry: int = _closest_index(passage, start)
	var exit_index: int = _closest_index(passage, goal)
	if entry == exit_index:
		return _nav_path(map, start, goal)

	var connector: PackedVector3Array = _nav_path(map, start, passage[entry])
	if connector.is_empty():
		return connector

	var result: PackedVector3Array = PackedVector3Array()
	_append_path(result, connector)
	var step: int = 1 if exit_index > entry else -1
	var index: int = entry
	while index != exit_index:
		var segment: PackedVector3Array = _nav_path(map, passage[index], passage[index + step])
		if segment.is_empty():
			return PackedVector3Array()

		_append_path(result, segment)
		index += step
	var tail: PackedVector3Array = _nav_path(map, passage[exit_index], goal)
	if tail.is_empty():
		return PackedVector3Array()

	_append_path(result, tail)
	return result

static func _closest_index(points: PackedVector3Array, position: Vector3) -> int:
	var closest: int = 0
	for index: int in range(1, points.size()):
		if points[index].distance_squared_to(position) < points[closest].distance_squared_to(position):
			closest = index
	return closest

static func _append_path(result: PackedVector3Array, segment: PackedVector3Array) -> void:
	for point: Vector3 in segment:
		if result.is_empty() or not result[result.size() - 1].is_equal_approx(point):
			result.append(point)

static func _local_detour(context: NpcRouteContext, path: PackedVector3Array, map: RID) -> PackedVector3Array:
	var margin: float = DistrictPopulationService.current().definition.local_detour_margin
	for index: int in range(1, path.size()):
		var start: Vector3 = path[index - 1]
		var goal: Vector3 = path[index]
		var forward: Vector3 = goal - start
		forward.y = 0.0
		if forward.is_zero_approx():
			continue

		forward = forward.normalized()
		var side: Vector3 = forward.cross(Vector3.UP)
		for hazard: NpcRouteContext.Hazard in context.hazards:
			var center: Vector3 = hazard.center
			center.y = start.y
			var extent: float = hazard.radius + margin
			if _inside_length(start, goal, center, extent) <= 0.0:
				continue
			if side.dot(start - center) < 0.0:
				side = -side
			var before: Vector3 = center - forward * extent + side * extent
			var after: Vector3 = center + forward * extent + side * extent
			var first: PackedVector3Array = _nav_path(map, start, before)
			var middle: PackedVector3Array = _nav_path(map, before, after)
			var last: PackedVector3Array = _nav_path(map, after, goal)
			if first.is_empty() or middle.is_empty() or last.is_empty():
				return PackedVector3Array()

			var result: PackedVector3Array = path.slice(0, index)
			_append_path(result, first)
			_append_path(result, middle)
			_append_path(result, last)
			_append_path(result, path.slice(index + 1))
			return result
	return PackedVector3Array()
#endregion

#region Общая оценка риска
## Обнаруживает реальную вредную область с учётом зазора вокруг тела и сферы опасности.
static func danger_here(actor: E_DistrictNpc) -> bool:
	for effect: Entity in _hazard_entities():
		var profile: DEF_ToxicArea = (effect.get_component(C_Hazard) as C_Hazard).definition as DEF_ToxicArea
		var spatial: Node3D = effect as Node as Node3D
		if profile != null and spatial != null and not effect.has_component(C_NoDamage) and DamageResistanceRules.effective(actor, profile.damage_per_tick, profile.damage_type) > 0.0 and spatial.global_position.distance_to(actor.global_position + Vector3.UP * NpcPerceptionService.TORSO_HEIGHT) < profile.radius + actor.navigation_agent.radius:
			return true
	return false

## Отступает от текущей вредной сферы; обычная навигация проверяет путь выхода.
static func refuge(actor: E_DistrictNpc) -> Vector3:
	var margin: float = DistrictPopulationService.current().definition.local_detour_margin
	for hazard: NpcRouteContext.Hazard in _hazards(actor):
		var outward: Vector3 = actor.global_position - hazard.center
		outward.y = 0.0
		if outward.length() >= hazard.radius:
			continue
		if outward.is_zero_approx():
			outward = actor.global_basis.x
			outward.y = 0.0
		var center: Vector3 = hazard.center
		center.y = actor.global_position.y
		return center + outward.normalized() * (hazard.radius + margin)
	return actor.global_position

## Ожидаемый периодический урон использует тот же множитель типа, что и O_Damage.
static func expected_damage(actor: Entity, path: PackedVector3Array) -> float:
	return _damage(path, _hazards(actor), _speed(actor))

## Обычное движение допускает малый риск; преследование сохраняет авторский запас здоровья.
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

static func _context(actor: E_DistrictNpc) -> NpcRouteContext:
	var context: NpcRouteContext = NpcRouteContext.new()
	context.hazards = _hazards(actor)
	context.speed = _speed(actor)
	return context

static func _nav_path(map: RID, start: Vector3, goal: Vector3) -> PackedVector3Array:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, goal, true)
	if path.is_empty() or path[path.size() - 1].distance_to(goal) > ENDPOINT_TOLERANCE:
		return PackedVector3Array()
	return path

#endregion
