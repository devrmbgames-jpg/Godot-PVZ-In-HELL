extends "res://tests/gut/test_district_population.gd"
## Native regression: hazard escape must choose a navigable endpoint outside harmful volumes.

const FIRE_SCENE: PackedScene = preload("res://content/domains/hazards/entities/npc_fire_aura.tscn")

var _map: RID = RID()
var _region: RID = RID()


func after_each() -> void:
	if _region.is_valid():
		NavigationServer3D.free_rid(_region)
	if _map.is_valid():
		NavigationServer3D.free_rid(_map)
	_region = RID()
	_map = RID()
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
