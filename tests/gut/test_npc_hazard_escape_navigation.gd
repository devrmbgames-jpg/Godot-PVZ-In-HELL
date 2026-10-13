extends "res://tests/gut/test_district_population.gd"
## Native regression: hazard escape must choose a navigable endpoint outside harmful volumes.

const FIRE_SCENE: PackedScene = preload("res://content/domains/hazards/entities/npc_fire_aura.tscn")

var _map: RID = RID()
var _region: RID = RID()
var _island: RID = RID()


func after_each() -> void:
	if _island.is_valid():
		NavigationServer3D.free_rid(_island)
	if _region.is_valid():
		NavigationServer3D.free_rid(_region)
	if _map.is_valid():
		NavigationServer3D.free_rid(_map)
	_region = RID()
	_map = RID()
	_island = RID()
	super.after_each()


func _bounded_map() -> E_DistrictNpc:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.vertices = PackedVector3Array(
		[Vector3(-10, 0, -10), Vector3(-10, 0, 10), Vector3(10, 0, 10), Vector3(10, 0, -10)]
	)
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	_map = NavigationServer3D.map_create()
	_region = NavigationServer3D.region_create()
	NavigationServer3D.map_set_active(_map, true)
	NavigationServer3D.region_set_map(_region, _map)
	NavigationServer3D.region_set_navigation_mesh(_region, mesh)
	for frame: int in 120:
		await get_tree().physics_frame
		if (
			NavigationServer3D.map_get_iteration_id(_map) > 0
			and NavigationServer3D.map_get_closest_point_owner(_map, Vector3.ZERO) == _region
		):
			break
	assert_gt(NavigationServer3D.map_get_iteration_id(_map), 0)
	assert_eq(NavigationServer3D.map_get_closest_point_owner(_map, Vector3.ZERO), _region)
	var person: NpcRecord = _district.people[0]
	var actor: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	assert_true(DistrictPopulationService.set_placement(person, actor, NpcRecord.Placement.STREET))
	actor.freeze = true
	actor.place_at(Vector3(8, 0, 0))
	actor.navigation_agent.set_navigation_map(_map)
	return actor


func _fire(center: Vector3, radius: float) -> Entity:
	var effect: Entity = FIRE_SCENE.instantiate() as Entity
	var definition: DEF_ToxicArea = DEF_ToxicArea.new()
	definition.radius = radius
	definition.floor_height = 0.2
	definition.damage_per_tick = 1.0
	definition.tick_seconds = 0.5
	definition.damage_type = DamageRequest.Type.FIRE
	var state: C_Hazard = C_Hazard.new()
	state.definition = definition
	_world.add_entity(effect, [state])
	(effect as Node as Node3D).global_position = center + Vector3.UP * 0.1
	return effect


func _escape(actor: E_DistrictNpc) -> PackedVector3Array:
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.hazard_distress = NpcRouteSolver.danger_here(actor)
	assert_true(awareness.hazard_distress)
	var goal: Vector3 = NpcRouteSolver.refuge(actor)
	var path: PackedVector3Array = NpcRouteSolver.plan(
		actor,
		_district.people[0],
		actor.global_position,
		goal,
		_map,
	)
	assert_false(path.is_empty(), "A safe endpoint on the connected native map remains reachable")
	return path


func test_existing_navigable_radial_exit_is_preserved() -> void:
	var actor: E_DistrictNpc = await _bounded_map()
	_fire(Vector3(7, 0, 0), 1.5)
	var radius: float = 1.5 + actor.navigation_agent.radius
	var goal: Vector3 = NpcRouteSolver.refuge(actor)
	var expected: Vector3 = Vector3(7, 0, 0) + Vector3.RIGHT * (
		radius + _district.definition.local_detour_margin
	)
	assert_almost_eq(goal, expected, Vector3.ONE * 0.001)
	assert_false(_escape(actor).is_empty())


## A wounded actor inside fire must still attempt the connected exit instead of waiting to die.
func test_low_health_escape_keeps_the_native_exit_when_predicted_exposure_exceeds_hp() -> void:
	var actor: E_DistrictNpc = await _bounded_map()
	_fire(Vector3(7, 0, 0), 5.0)
	var health: C_Health = actor.get_component(C_Health) as C_Health
	health.current = 0.5
	var path: PackedVector3Array = _escape(actor)
	if path.is_empty():
		return
	assert_gt(NpcRouteSolver.expected_damage(actor, path), health.current)
	assert_gt(
		path[path.size() - 1].distance_to(Vector3(7, 0, 0)), 5.0 + actor.navigation_agent.radius,
	)
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.hazard_distress = false
	var ordinary: PackedVector3Array = NpcRouteSolver.plan(
		actor, _district.people[0], actor.global_position, path[path.size() - 1], _map,
	)
	assert_true(ordinary.is_empty(), "Ordinary travel retains its authored damage budget")


func test_fire_immunity_does_not_request_hazard_escape() -> void:
	var actor: E_DistrictNpc = await _bounded_map()
	_fire(Vector3(7, 0, 0), 5.0)
	var resistance: C_DamageResistance = (
		actor.get_component(C_DamageResistance) as C_DamageResistance
	)
	resistance.multipliers[DamageRequest.Type.FIRE] = 0.0
	assert_false(NpcRouteSolver.danger_here(actor))
	assert_eq(NpcRouteSolver.refuge(actor), actor.global_position)


func test_escape_near_map_edge_reaches_outside_fire_instead_of_a_clamped_inside_endpoint() -> void:
	var actor: E_DistrictNpc = await _bounded_map()
	_fire(Vector3(7, 0, 0), 5.0)
	var path: PackedVector3Array = _escape(actor)
	if path.is_empty():
		return
	var endpoint: Vector3 = path[path.size() - 1]
	assert_gt(endpoint.distance_to(Vector3(7, 0, 0)), 5.0 + actor.navigation_agent.radius)
	assert_lte(absf(endpoint.x), 10.0)
	assert_lte(absf(endpoint.z), 10.0)


func test_escape_at_minimum_authored_detour_margin_clears_arrival_tolerance() -> void:
	var actor: E_DistrictNpc = await _bounded_map()
	_district.definition = _district.definition.duplicate() as DEF_District
	_district.definition.local_detour_margin = 0.1
	_fire(Vector3(7, 0, 0), 5.0)
	var path: PackedVector3Array = _escape(actor)
	if path.is_empty():
		return
	var endpoint: Vector3 = path[path.size() - 1]
	assert_gt(
		endpoint.distance_to(Vector3(7, 0, 0)),
		5.0 + actor.navigation_agent.radius + NpcDecisionService.ARRIVAL_DISTANCE,
	)


func test_escape_endpoint_avoids_a_second_overlapping_hazard() -> void:
	var actor: E_DistrictNpc = await _bounded_map()
	_fire(Vector3(7, 0, 0), 5.0)
	_fire(Vector3(7, 0, 5), 3.0)
	var path: PackedVector3Array = _escape(actor)
	if path.is_empty():
		return
	var endpoint: Vector3 = path[path.size() - 1]
	assert_gt(endpoint.distance_to(Vector3(7, 0, 0)), 5.0 + actor.navigation_agent.radius)
	assert_gt(endpoint.distance_to(Vector3(7, 0, 5)), 3.0 + actor.navigation_agent.radius)


## A moving refuge can shift below the waypoint threshold after the native agent finishes.
func test_finished_stale_endpoint_replans_to_the_current_movement_goal() -> void:
	var actor: E_DistrictNpc = await _bounded_map()
	var person: NpcRecord = _district.people[0]
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	var old_goal: Vector3 = Vector3(8.8, 0, 0)
	route.points = NpcRouteSolver.plan(actor, person, actor.global_position, old_goal, _map)
	assert_false(route.points.is_empty())
	route.goal = old_goal
	route.navigation_map = _map
	route.map_iteration = NavigationServer3D.map_get_iteration_id(_map)
	route.point_index = route.points.size() - 1
	route.reachable = true
	intent.movement_active = true
	intent.navigation_enabled = true
	intent.move_position = Vector3(9.08, 0, 0)
	intent.arrival_distance = NpcDecisionService.ARRIVAL_DISTANCE
	actor.place_at(Vector3(8.65, 0, 0))
	actor.navigation_agent.avoidance_enabled = false
	var owner: S_NpcIntent = S_NpcIntent.new()
	owner.group = "stale_endpoint_fixture"
	_world.add_system(owner)
	_world.process(0.0, owner.group)
	_world.remove_system(owner)
	assert_false(intent.arrived)
	assert_true(intent.navigation_blocked, "Native agent finished before the current goal")
	assert_lt(old_goal.distance_to(intent.move_position), _district.definition.waypoint_distance)
	NpcAiFixture.route(actor, person, 0.2)
	assert_true(route.pending, "The finished stale route must rejoin the fair planning queue")
	assert_true(_district.pending_routes.has(person.npc_id))
	NpcAiFixture.plan_routes(_district)
	assert_false(route.pending)
	assert_true(route.reachable)
	assert_almost_eq(route.goal, intent.move_position, Vector3.ONE * 0.001)
	assert_almost_eq(
		route.points[route.points.size() - 1], intent.move_position, Vector3.ONE * 0.001,
	)
	var stable: PackedVector3Array = route.points.duplicate()
	NpcAiFixture.route(actor, person, 0.2)
	assert_false(route.pending, "The same blocked observation does not requeue an unchanged goal")
	assert_false(_district.pending_routes.has(person.npc_id))
	assert_eq(route.points, stable)


## A projected safe island cannot mask a reachable safe exit on the actor's connected region.
func test_failed_disconnected_refuge_yields_to_a_connected_safe_candidate() -> void:
	var actor: E_DistrictNpc = await _bounded_map()
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.vertices = PackedVector3Array([
		Vector3(11, 0, -3), Vector3(11, 0, 3), Vector3(14, 0, 3), Vector3(14, 0, -3),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	_island = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_island, _map)
	NavigationServer3D.region_set_navigation_mesh(_island, mesh)
	for frame: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_closest_point_owner(_map, Vector3(12, 0, 0)) == _island:
			break
	assert_eq(NavigationServer3D.map_get_closest_point_owner(_map, Vector3(12, 0, 0)), _island)
	var effect: Entity = _fire(Vector3(7, 0, 0), 5.0)
	var person: NpcRecord = _district.people[0]
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.hazard_distress = NpcRouteSolver.danger_here(actor)
	assert_true(awareness.hazard_distress)
	var first: Vector3 = NpcRouteSolver.refuge(actor)
	assert_eq(NavigationServer3D.map_get_closest_point_owner(_map, first), _island)
	NpcIntentService.move_to(actor, first, NpcDecisionService.ARRIVAL_DISTANCE)
	NpcAiFixture.route(actor, person, 0.2)
	NpcAiFixture.plan_routes(_district)
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	assert_false(route.reachable, "The native map cannot connect the first safe island")
	assert_true(route.rejected_refuge_points.has(first))
	assert_eq(route.refuge_direction_offset, 1)
	var alternative: Vector3 = NpcRouteSolver.refuge(actor)
	assert_eq(
		NavigationServer3D.map_get_closest_point_owner(_map, alternative), _region,
		"Actual failed planning must select a different safe candidate on the connected region",
	)
	(effect as Node as Node3D).global_position = Vector3(7, 0.1, 0.6)
	alternative = NpcRouteSolver.refuge(actor)
	assert_eq(
		NavigationServer3D.map_get_closest_point_owner(_map, alternative), _region,
		"A moving hazard must not restart candidate selection on the same disconnected island",
	)
	NpcIntentService.move_to(actor, alternative, NpcDecisionService.ARRIVAL_DISTANCE)
	NpcAiFixture.route(actor, person, 0.2)
	await get_tree().physics_frame
	NpcAiFixture.plan_routes(_district)
	assert_true(route.reachable)
	assert_false(route.points.is_empty())
	if not route.points.is_empty():
		assert_gt(
			route.points[route.points.size() - 1].distance_to(Vector3(7, 0, 0.6)),
			5.0 + actor.navigation_agent.radius + NpcDecisionService.ARRIVAL_DISTANCE,
		)
		var retained_goal: Vector3 = route.goal
		actor.place_at(actor.global_position.move_toward(retained_goal, 0.75))
		assert_almost_eq(
			NpcRouteSolver.refuge(actor), retained_goal, Vector3.ONE * 0.001,
			"A successful safe escape retains its world goal while the actor advances",
		)
		(effect as Node as Node3D).global_position = retained_goal + Vector3.UP * 0.1
		var moved_goal: Vector3 = NpcRouteSolver.refuge(actor)
		assert_false(moved_goal.is_equal_approx(retained_goal))
		assert_gt(
			moved_goal.distance_to(retained_goal),
			5.0 + actor.navigation_agent.radius + NpcDecisionService.ARRIVAL_DISTANCE,
			"A moving hazard invalidates the retained endpoint when it becomes unsafe",
		)
	actor.place_at(Vector3(8, 0, 0))
	awareness.hazard_distress = false
	NpcAiFixture.route(actor, person, 0.2)
	assert_true(route.rejected_refuge_points.is_empty(), "Leaving danger retires derived feedback")
	assert_eq(route.refuge_direction_offset, 0)
	(effect as Node as Node3D).global_position = Vector3(7, 0.1, 0)
	awareness.hazard_distress = true
	NpcIntentService.move_to(actor, first, NpcDecisionService.ARRIVAL_DISTANCE)
	NpcAiFixture.route(actor, person, 0.2)
	await get_tree().physics_frame
	NpcAiFixture.plan_routes(_district)
	assert_true(route.rejected_refuge_points.has(first))
	route.refuge_direction_offset = NpcRouteSolver.REFUGE_DIRECTION_COUNT - 1
	actor.navigation_agent.set_navigation_map(actor.get_world_3d().navigation_map)
	assert_ne(actor.navigation_agent.get_navigation_map(), _map)
	NpcIntentService.move_to(actor, first + Vector3.FORWARD, NpcDecisionService.ARRIVAL_DISTANCE)
	NpcAiFixture.route(actor, person, 0.2)
	assert_true(route.pending, "Changed goal queues before the map polling interval")
	await get_tree().physics_frame
	NpcAiFixture.plan_routes(_district)
	assert_eq(route.navigation_map, actor.navigation_agent.get_navigation_map())
	assert_false(route.reachable, "The new empty map records its own failed plan")
	assert_eq(route.refuge_direction_offset, 1, "New map starts a fresh candidate cycle")
	assert_false(
		route.rejected_refuge_points.has(first),
		"Planning on a new native map retires feedback before publishing map identity",
	)
