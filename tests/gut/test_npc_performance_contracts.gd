extends "res://tests/gut/test_district_population.gd"
## Real lighting, world replacement and fair route scheduling preserve behavior after optimization.

var _native_map: RID = RID()
var _native_region: RID = RID()

#region Fixtures
## Releases the native test map before the inherited world fixture.
func after_each() -> void:
	if _native_region.is_valid():
		NavigationServer3D.free_rid(_native_region)
	if _native_map.is_valid():
		NavigationServer3D.free_rid(_native_map)
	_native_region = RID()
	_native_map = RID()
	super.after_each()

func _flat_map() -> void:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-100, 0, -100), Vector3(-100, 0, 100), Vector3(100, 0, 100), Vector3(100, 0, -100)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	_native_map = NavigationServer3D.map_create()
	_native_region = NavigationServer3D.region_create()
	NavigationServer3D.map_set_active(_native_map, true)
	NavigationServer3D.region_set_map(_native_region, _native_map)
	NavigationServer3D.region_set_navigation_mesh(_native_region, mesh)
	for frame: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_native_map) > 0 and NavigationServer3D.map_get_closest_point_owner(_native_map, Vector3.ZERO) == _native_region:
			break
	assert_gt(NavigationServer3D.map_get_iteration_id(_native_map), 0)

func _travel(index: int) -> E_DistrictNpc:
	var person: NpcRecord = _district.people[index]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	body.freeze = true
	body.place_at(Vector3(-8, 0, index * 3))
	body.navigation_agent.set_navigation_map(_native_map)
	NpcIntentService.move_to(body, Vector3(8, 0, index * 3), 0.3)
	NpcRouteService.tick(body, person, 0.2)
	return body

func _lamp(circuit_id: StringName = &"") -> OmniLight3D:
	_district.definition = DEF_District.new()
	_district.lighting_context = null
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.omni_range = 10.0
	lamp.light_energy = 4.0
	_root.add_child(lamp)
	lamp.position = Vector3(80, 3, 0)
	if not circuit_id.is_empty():
		var view: CircuitLightView = CircuitLightView.new()
		view.name = "CircuitLightView"
		view.circuit_id = circuit_id
		lamp.add_child(view)
		view.set_process(false)
	_district.light_sources.append(lamp)
	return lamp

func _circuit() -> Entity:
	var circuit: Entity = Entity.new()
	var state: C_LightCircuit = C_LightCircuit.new()
	state.circuit_id = &"performance_test"
	state.light_groups = [&"performance_test_lamps"]
	circuit.component_resources = [state]
	_world.add_entity(circuit)
	return circuit
#endregion

#region Lookup lifecycle
## A replacement component and a removed body cannot leave stale singleton/cache results.
func test_replaced_session_and_removed_body_refresh_lookups() -> void:
	assert_same(DistrictPopulationService.current(), _district)
	var old_body: E_DistrictNpc = DistrictPopulationService.body_for(_district.people[0].npc_id)
	_world.remove_entity(old_body)
	assert_null(DistrictPopulationService.body_for(_district.people[0].npc_id))
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.remove_component(C_District)
	var replacement: C_District = C_District.new()
	session.add_component(replacement)
	assert_same(DistrictPopulationService.current(), replacement)

## Caches are scene-local even when two worlds live at once during restoration.
func test_world_switch_never_reuses_previous_session_or_circuit() -> void:
	var old_circuit: Entity = _circuit()
	assert_same(LightCircuitService.entity_for(&"performance_test"), old_circuit)
	var replacement_world: World = World.new()
	_root.add_child(replacement_world)
	ECS.world = replacement_world
	var session: Entity = Entity.new()
	session.component_resources = [C_District.new()]
	replacement_world.add_entity(session)
	assert_same(DistrictPopulationService.current(), session.get_component(C_District))
	assert_null(LightCircuitService.entity_for(&"performance_test"))
	replacement_world.purge(false)
	replacement_world.free()
	ECS.world = _world
	assert_same(DistrictPopulationService.current(), _district)
	assert_same(LightCircuitService.entity_for(&"performance_test"), old_circuit)

## Replacing a circuit under the same authored ID replaces the cached binding.
func test_removed_circuit_does_not_keep_old_state() -> void:
	var old_circuit: Entity = _circuit()
	assert_same(LightCircuitService.entity_for(&"performance_test"), old_circuit)
	_world.remove_entity(old_circuit)
	var replacement: Entity = _circuit()
	assert_same(LightCircuitService.entity_for(&"performance_test"), replacement)
#endregion

#region Lighting
## Shared input data must observe toggles and flicker even within the same physics frame.
func test_switch_and_flicker_change_shared_lighting_immediately() -> void:
	_world.add_observer(O_LightFlicker.new())
	var circuit: Entity = _circuit()
	var lamp: OmniLight3D = _lamp(&"performance_test")
	lamp.add_to_group(&"performance_test_lamps")
	var point: Vector3 = Vector3(80, 1, 0)
	assert_gt(NpcLightingService.exposure_at(point), 0.5)
	LightCircuitService.set_enabled(circuit, false)
	assert_eq(NpcLightingService.exposure_at(point), 0.05)
	LightCircuitService.set_enabled(circuit, true)
	assert_gt(NpcLightingService.exposure_at(point), 0.5)
	assert_true(LightCircuitService.flicker(&"performance_test", 2.0, 0.1))
	(lamp.get_node("CircuitLightView") as CircuitLightView)._process(0.15)
	assert_eq(NpcLightingService.exposure_at(point), 0.05)
	LightCircuitService.set_enabled(circuit, false)
	_world.remove_entity(circuit)
	var replacement: Entity = _circuit()
	LightCircuitService.set_enabled(replacement, true)
	assert_gt(NpcLightingService.exposure_at(point), 0.5, "Structural replacement must refresh shared circuit bindings in the same frame")

## Physical occlusion and exclusion lists remain specific to each query.
func test_shared_lighting_preserves_blockers_and_excluded_bodies() -> void:
	_lamp()
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4, 0.2, 4)
	collision.shape = shape
	wall.add_child(collision)
	_root.add_child(wall)
	wall.position = Vector3(80, 2, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var point: Vector3 = Vector3(80, 1, 0)
	assert_eq(NpcLightingService.exposure_at(point), 0.05)
	assert_gt(NpcLightingService.exposure_at(point, [wall.get_rid()]), 0.5)
	assert_eq(NpcLightingService.exposure_at(point), 0.05)
	wall.position.x = 70
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_gt(NpcLightingService.exposure_at(point), 0.5)

## Moving the level origin is reflected in the next authored-input snapshot.
func test_authored_place_positions_follow_origin_between_frames() -> void:
	_district.definition = DEF_District.new()
	var dark: DEF_DistrictPlace = DEF_DistrictPlace.new()
	dark.key = &"dark"
	dark.ambient_light = 0.1
	var bright: DEF_DistrictPlace = DEF_DistrictPlace.new()
	bright.key = &"bright"
	bright.position = Vector3(10, 0, 0)
	bright.ambient_light = 0.9
	_district.definition.places = [dark, bright]
	assert_almost_eq(NpcLightingService.exposure_at(Vector3(10, 1, 0)), 0.9, 0.001)
	(_root.get_node("District") as Node3D).position.x = 20
	await get_tree().physics_frame
	assert_almost_eq(NpcLightingService.exposure_at(Vector3(30, 1, 0)), 0.9, 0.001)
	assert_almost_eq(NpcLightingService.exposure_at(Vector3(20, 1, 0)), 0.1, 0.001)
#endregion

#region Planning queue
## Light-sensitive travel chooses the dark graph route, then observes a switched-off lamp.
func test_light_sensitive_route_reacts_without_reusing_old_light_costs() -> void:
	await _flat_map()
	var actor: E_DistrictNpc = _travel(0)
	var person: NpcRecord = _district.people[0]
	person.profile = person.profile.duplicate(true) as DEF_NpcProfile
	var aversion: DEF_NpcTrait = DEF_NpcTrait.new()
	aversion.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	aversion.light_threshold = 0.4
	person.profile.rules = [aversion]
	_district.definition = DEF_District.new()
	_district.definition.light_route_penalty = 40.0
	_district.lighting_context = null
	var points: Array[Vector3] = [Vector3(-8, 0, 0), Vector3(-8, 0, 8), Vector3(8, 0, 8), Vector3(8, 0, 0)]
	for index: int in points.size():
		var place: DEF_DistrictPlace = DEF_DistrictPlace.new()
		place.kind = DEF_DistrictPlace.Kind.JUNCTION
		place.key = StringName("junction_%d" % index)
		place.position = points[index]
		place.ambient_light = 0.05
		if index > 0:
			place.neighbours.append("junction_%d" % (index - 1))
		if index < points.size() - 1:
			place.neighbours.append("junction_%d" % (index + 1))
		_district.definition.places.append(place)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.omni_range = 6.0
	lamp.light_energy = 8.0
	_root.add_child(lamp)
	lamp.position = Vector3(0, 2, 0)
	_district.light_sources.append(lamp)
	var lit_route: PackedVector3Array = NpcRouteService.plan(actor, person, points[0], points[3], _native_map)
	assert_gt(lit_route.size(), 2, "A longer dark passage is preferable to the illuminated direct route")
	lamp.visible = false
	var dark_route: PackedVector3Array = NpcRouteService.plan(actor, person, points[0], points[3], _native_map)
	assert_eq(dark_route.size(), 2, "Lighting costs are refreshed for each plan")

## A later request cannot jump the queue, and repeated processing cannot exceed the frame cap.
func test_route_queue_is_fair_and_limited_per_physics_frame() -> void:
	await _flat_map()
	var first: E_DistrictNpc = _travel(0)
	var second: E_DistrictNpc = _travel(3)
	var first_route: C_NpcRoute = first.get_component(C_NpcRoute) as C_NpcRoute
	var second_route: C_NpcRoute = second.get_component(C_NpcRoute) as C_NpcRoute
	assert_true(first_route.pending)
	assert_true(second_route.pending)
	assert_false(first_route.reachable, "Pending initial route must wait instead of entering danger")
	NpcRouteService.process_pending(_district)
	assert_false(first_route.pending)
	assert_true(first_route.reachable)
	assert_true(second_route.pending)
	NpcRouteService.tick(first, _district.people[0], _district.definition.route_interval)
	NpcRouteService.process_pending(_district)
	assert_true(second_route.pending, "The same frame has already spent its allowance")
	await get_tree().physics_frame
	NpcRouteService.process_pending(_district)
	assert_false(second_route.pending, "Earlier waiting traveler runs before the new refresh")
	assert_true(second_route.reachable)
	assert_true(first_route.pending)

## An interrupted action cannot commit its old route after a delayed queue slot.
func test_cancelled_queued_route_is_discarded() -> void:
	await _flat_map()
	var actor: E_DistrictNpc = _travel(0)
	NpcIntentService.stop(actor)
	NpcRouteService.process_pending(_district)
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	assert_false(route.pending)
	assert_true(route.points.is_empty())
	assert_false((actor.get_component(C_NpcIntent) as C_NpcIntent).movement_active)

## A changed destination uses the current intent when the queued work finally executes.
func test_queued_route_uses_latest_goal() -> void:
	await _flat_map()
	var actor: E_DistrictNpc = _travel(0)
	var goal: Vector3 = Vector3(5, 0, 5)
	NpcIntentService.move_to(actor, goal, 0.3)
	NpcRouteService.process_pending(_district)
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	assert_eq(route.goal, goal)
	assert_lt(route.points[route.points.size() - 1].distance_to(goal), 0.1)
#endregion
