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

func _zone(circuit_id: StringName = &"") -> NpcLightZone:
	var zone: NpcLightZone = (load("res://content/scenes/npc_light_zone.tscn") as PackedScene).instantiate() as NpcLightZone
	zone.circuit_id = circuit_id
	zone.moving_source = true
	if not circuit_id.is_empty():
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.name = "Lamp"
		lamp.add_to_group(&"performance_test_lamps")
		zone.add_child(lamp)
		var view: CircuitLightView = CircuitLightView.new()
		view.name = "CircuitLightView"
		view.circuit_id = circuit_id
		lamp.add_child(view)
		view.set_process(false)
		zone.flicker_view_path = NodePath("Lamp/CircuitLightView")
	_root.add_child(zone)
	zone.position = Vector3(80, 1, 0)
	return zone

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
	var zone: NpcLightZone = _zone(&"performance_test")
	var point: Vector3 = Vector3(80, 1, 0)
	assert_gt(NpcLightingService.exposure_at(point), 0.5)
	LightCircuitService.set_enabled(circuit, false)
	assert_eq(NpcLightingService.exposure_at(point), 0.05)
	LightCircuitService.set_enabled(circuit, true)
	assert_gt(NpcLightingService.exposure_at(point), 0.5)
	assert_true(LightCircuitService.flicker(&"performance_test", 2.0, 0.1))
	(zone.get_node("Lamp/CircuitLightView") as CircuitLightView)._process(0.15)
	assert_eq(NpcLightingService.exposure_at(point), 0.05)
	LightCircuitService.set_enabled(circuit, false)
	_world.remove_entity(circuit)

	var replacement: Entity = _circuit()
	LightCircuitService.set_enabled(replacement, true)
	assert_gt(NpcLightingService.exposure_at(point), 0.5, "Structural replacement must refresh shared circuit bindings in the same frame")

## Props cannot hide the exposure of an authored room; its boundaries define darkness.
func test_manual_zone_boundaries_do_not_require_light_rays() -> void:
	var zone: NpcLightZone = _zone()
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4, 0.2, 4)
	collision.shape = shape
	wall.add_child(collision)
	_root.add_child(wall)
	wall.position = Vector3(80, 2, 0)
	assert_eq(NpcLightingService.exposure_at(Vector3(80, 1, 0)), 1.0)
	assert_eq(NpcLightingService.exposure_at(Vector3(80, 1, 0), [wall.get_rid()]), 1.0)
	assert_eq(NpcLightingService.exposure_at(Vector3(85, 1, 0)), 0.05)
	zone.enabled = false
	assert_eq(NpcLightingService.exposure_at(Vector3(80, 1, 0)), 0.05)

## A carried light follows transform changes and leaves no binding after removal/reattachment.
func test_moving_zone_updates_without_rebuilding_inputs() -> void:
	var zone: NpcLightZone = _zone()
	var context: NpcLightingContext = NpcLightingService.context_for(_district)
	assert_eq(NpcLightingService.exposure_at(Vector3(80, 1, 0)), 1.0)
	zone.position.x = 90.0
	assert_eq(NpcLightingService.exposure_at(Vector3(80, 1, 0)), 0.05)
	assert_eq(NpcLightingService.exposure_at(Vector3(90, 1, 0)), 1.0)
	assert_same(NpcLightingService.context_for(_district), context)

	var volume: CollisionShape3D = zone.get_node("CollisionShape3D") as CollisionShape3D
	var beam: BoxShape3D = BoxShape3D.new()
	beam.size = Vector3(6, 3, 2)
	volume.shape = beam
	zone.rotation.y = PI * 0.5
	assert_eq(NpcLightingService.exposure_at(Vector3(90, 1, 2)), 1.0)
	assert_eq(NpcLightingService.exposure_at(Vector3(92, 1, 0)), 0.05)
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 3.0
	volume.shape = sphere
	assert_eq(NpcLightingService.exposure_at(Vector3(92, 1, 0)), 1.0)
	_root.remove_child(zone)
	assert_eq(NpcLightingService.exposure_at(Vector3(90, 1, 0)), 0.05)
	_root.add_child(zone)
	assert_eq(NpcLightingService.exposure_at(Vector3(90, 1, 0)), 1.0)
	zone.free()
	assert_eq(NpcLightingService.exposure_at(Vector3(90, 1, 0)), 0.05)

## Other loaded levels do not contribute volumes to the active world's lighting.
func test_zone_registration_is_scoped_to_the_world_level() -> void:
	var other_root: Node3D = Node3D.new()
	add_child(other_root)
	var zone: NpcLightZone = (load("res://content/scenes/npc_light_zone.tscn") as PackedScene).instantiate() as NpcLightZone
	other_root.add_child(zone)
	zone.position = Vector3(80, 1, 0)
	assert_eq(NpcLightingService.exposure_at(Vector3(80, 1, 0)), 0.05)
	other_root.free()

#endregion

#region Planning queue
## The authored passage is followed in both directions, independently of light changes.
func test_light_sensitive_route_follows_authored_points_without_light_search() -> void:
	await _flat_map()
	var actor: E_DistrictNpc = _travel(0)
	var person: NpcRecord = _district.people[0]
	person.profile = person.profile.duplicate(true) as DEF_NpcProfile
	var aversion: DEF_NpcTrait = DEF_NpcTrait.new()
	aversion.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	aversion.light_threshold = 0.4
	person.profile.rules = [aversion]
	_district.definition = DEF_District.new()
	_district.lighting_context = null

	var points: Array[Vector3] = [Vector3(-8, 0, 0), Vector3(-8, 0, 8), Vector3(8, 0, 8), Vector3(8, 0, 0)]
	for index: int in points.size():
		var place: DEF_DistrictPlace = DEF_DistrictPlace.new()
		place.kind = DEF_DistrictPlace.Kind.JUNCTION
		place.key = StringName("junction_%d" % index)
		place.position = points[index]
		_district.definition.places.append(place)
		_district.definition.shade_route.append(String(place.key))
	_district.definition.shade_refuge = &"junction_1"

	var zone: NpcLightZone = _zone()
	zone.position = Vector3(0, 1, 0)
	_district.lighting_context = null
	var lit_route: PackedVector3Array = NpcRouteService.plan(actor, person, points[0], points[3], _native_map)
	assert_eq(lit_route.size(), points.size())
	for index: int in mini(lit_route.size(), points.size()):
		assert_lt(lit_route[index].distance_to(points[index]), 0.001)
	assert_null(_district.lighting_context, "Planning must not request illumination samples")
	assert_eq(NpcTraitService.dark_refuge(actor, person), points[1])
	zone.enabled = false

	var dark_route: PackedVector3Array = NpcRouteService.plan(actor, person, points[0], points[3], _native_map)
	assert_eq(dark_route, lit_route, "Switching the light changes reactions, not authored routing")
	points.reverse()
	var reverse_route: PackedVector3Array = NpcRouteService.plan(actor, person, points[0], points[3], _native_map)
	assert_eq(reverse_route.size(), points.size())
	for index: int in mini(reverse_route.size(), points.size()):
		assert_lt(reverse_route[index].distance_to(points[index]), 0.001)
	_district.definition.places[1].position = Vector3(300, 0, 300)
	assert_true(NpcRouteService.plan(actor, person, points[3], points[0], _native_map).is_empty(), "An unreachable authored passage must not silently take another route")

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
	NpcIntentService.move_to(first, Vector3(8, 0, 2), 0.3)
	NpcRouteService.tick(first, _district.people[0], 0.2)
	NpcRouteService.process_pending(_district)
	assert_true(second_route.pending, "The same frame has already spent its allowance")
	await get_tree().physics_frame
	NpcRouteService.process_pending(_district)
	assert_false(second_route.pending, "Earlier waiting traveler runs before the new refresh")
	assert_true(second_route.reachable)
	assert_true(first_route.pending)

## An unchanged reachable route is retained across timer ticks and lighting changes.
func test_stable_goal_does_not_rebuild_route_on_each_risk_check() -> void:
	await _flat_map()
	var actor: E_DistrictNpc = _travel(0)
	NpcRouteService.process_pending(_district)
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	var original: PackedVector3Array = route.points.duplicate()
	for check: int in 3:
		NpcRouteService.tick(actor, _district.people[0], _district.definition.route_interval)
		assert_false(route.pending)
		assert_true(_district.pending_routes.is_empty())
		assert_eq(route.points, original)

## A new harmful overlap stops a retained path before a queued bypass can replace it.
func test_moving_hazard_invalidates_retained_route_before_movement() -> void:
	await _flat_map()
	var actor: E_DistrictNpc = _travel(0)
	NpcRouteService.process_pending(_district)
	var fire: Entity = (load("res://content/entities/hazards/npc_fire_aura.tscn") as PackedScene).instantiate() as Entity
	var hazard: C_Hazard = C_Hazard.new()
	hazard.definition = load("res://content/definitions/gameplay/hazards/def_npc_fire_aura.tres") as DEF_ToxicArea
	_world.add_entity(fire, [hazard])
	(fire as Node as Node3D).global_position = Vector3(0, 1, 0)
	NpcRouteService.tick(actor, _district.people[0], _district.definition.route_interval)

	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	assert_true(route.pending)
	assert_false(route.reachable)
	assert_true(route.points.is_empty())
	await get_tree().physics_frame
	NpcRouteService.process_pending(_district)
	assert_true(route.reachable)
	assert_eq(NpcRouteService.expected_damage(actor, route.points), 0.0)

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
