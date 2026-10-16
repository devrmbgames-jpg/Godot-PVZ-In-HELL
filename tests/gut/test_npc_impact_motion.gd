extends GutTest
## Native NPC damage and bounded external motion, including authored held/support contacts.

const NPC_SCENE: PackedScene = preload("res://content/domains/npc/entities/npc_character.tscn")
const BARREL_SCENE: PackedScene = preload(
	"res://content/domains/hazards/entities/blood_barrel.tscn"
)
const DELTA: float = 1.0 / 60.0
const SAMPLE_FRAMES: int = 120
## Floating-point tolerance in metres at the sampled native contact boundary.
const POSITION_EPSILON: float = 0.0001

var _world: World
var _npc: E_NpcCharacter
var _body: CharacterBody3D
var _health: C_Health
var _original_physics_rate: int = 60


## Observes committed health receipts without bypassing native contact or damage owners.
class DamageRecorder extends Observer:
	## Receipts live only for this fixture.
	var results: Array[DamageResult] = []


	func query() -> QueryBuilder:
		return q.with_all([C_Health]).on_event(DamageResult.EVENT)


	func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
		results.append(payload as DamageResult)


#region Native contact fixture
func before_each() -> void:
	_original_physics_rate = Engine.physics_ticks_per_second
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_GrabLifecycle.new())
	_world.add_system(S_Impact.new())
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = Vector3(30.0, 0.5, 30.0)
	floor_body.add_child(_collider(floor_shape))
	floor_body.position.y = -0.25
	_world.add_child(floor_body)
	_npc = NPC_SCENE.instantiate() as E_NpcCharacter
	EntityCompositionFixture.register(_world, _npc)
	_body = _npc as Node as CharacterBody3D
	_body.global_position = Vector3(0.0, 0.02, 0.0)
	_health = _npc.get_component(C_Health) as C_Health
	_health.value = 100.0
	_health.current = 100.0
	for frame: int in 12:
		await _tick()
	_health.current = 100.0


func after_each() -> void:
	Engine.physics_ticks_per_second = _original_physics_rate
	_world.purge(false)
	_world.free()
	ECS.world = null
	await get_tree().process_frame


func _collider(shape: Shape3D) -> CollisionShape3D:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	return collision


func _tick() -> Array[PhysicsContact]:
	await get_tree().physics_frame
	await get_tree().process_frame
	var contacts: Array[PhysicsContact] = []
	for entity: Entity in _world.query.with_all([C_ImpactInbox]).execute():
		var inbox: C_ImpactInbox = entity.get_component(C_ImpactInbox) as C_ImpactInbox
		for contact: PhysicsContact in inbox.contacts:
			if contact.body_a == _body or contact.body_b == _body:
				contacts.append(contact)
	_world.process(DELTA)
	return contacts


func _measure_free_impact(
	projectile_mass: float,
	projectile_speed: float,
	obstacle: PhysicsBody3D = null,
) -> Dictionary:
	var projectile: RigidBody3D = RigidBody3D.new()
	projectile.mass = projectile_mass
	projectile.gravity_scale = 0.0
	projectile.linear_damp = 0.0
	projectile.angular_damp = 0.0
	projectile.continuous_cd = true
	projectile.collision_layer = 4
	projectile.collision_mask = 3
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.7
	projectile.add_child(_collider(shape))
	_world.add_child(projectile)
	var result: Dictionary = await _sample_projectile(projectile, projectile_speed, obstacle)
	projectile.free()
	return result


func _sample_projectile(
	projectile: RigidBody3D,
	projectile_speed: float,
	obstacle: PhysicsBody3D = null,
) -> Dictionary:
	projectile.global_position = Vector3(0.0, 0.85, -3.0)
	projectile.linear_velocity = Vector3(0.0, 0.0, projectile_speed)
	var origin: Vector3 = _body.global_position
	var peak_speed: float = 0.0
	var peak_upward: float = 0.0
	var maximum_height: float = origin.y
	var maximum_displacement: float = 0.0
	var contact_seen: bool = false
	var obstacle_seen: bool = false
	for frame: int in SAMPLE_FRAMES:
		var contacts: Array[PhysicsContact] = await _tick()
		peak_speed = maxf(peak_speed, Vector2(_body.velocity.x, _body.velocity.z).length())
		peak_upward = maxf(peak_upward, _body.velocity.y)
		maximum_height = maxf(maximum_height, _body.global_position.y)
		maximum_displacement = maxf(maximum_displacement, _body.global_position.distance_to(origin))
		for contact: PhysicsContact in contacts:
			if contact.body_b == projectile or contact.body_a == projectile:
				contact_seen = true
			if obstacle != null and (contact.body_a == obstacle or contact.body_b == obstacle):
				obstacle_seen = true
	var result: Dictionary = {
		"native_body": _body.get_class(),
		"npc_mass": (_npc.get_component(C_CharacterBody) as C_CharacterBody).mass_kg,
		"projectile_mass": projectile.mass,
		"projectile_speed": projectile_speed,
		"contact_seen": contact_seen,
		"obstacle_seen": obstacle_seen,
		"health": _health.current,
		"peak_planar_speed": peak_speed,
		"peak_upward_speed": peak_upward,
		"maximum_height": maximum_height,
		"maximum_displacement": maximum_displacement,
		"frames": SAMPLE_FRAMES,
	}
	print("NATIVE_NPC_IMPACT_PROBE " + JSON.stringify(result))
	return result


func _spawn_barrel() -> E_GrabbableBody:
	var barrel: E_GrabbableBody = BARREL_SCENE.instantiate() as E_GrabbableBody
	EntityCompositionFixture.register(_world, barrel)
	return barrel


func _grip_holder() -> E_RigidBodyCharacter:
	var rigid: RigidBody3D = RigidBody3D.new()
	rigid.set_script(E_RigidBodyCharacter)
	rigid.freeze = true
	rigid.collision_layer = 0
	var holder: E_RigidBodyCharacter = rigid as Node as E_RigidBodyCharacter
	holder.component_resources = [
		C_Controller.new(),
		C_GrabControl.new(),
		C_CarryLoad.new(),
		C_Strength.new(),
		C_Interactor.new(),
		C_Health.new(),
		C_ImpactInbox.new(),
	]
	var anchor: Marker3D = Marker3D.new()
	anchor.position.y = 0.85
	rigid.add_child(anchor)
	holder.hold_anchor = anchor
	var ray: RayCast3D = RayCast3D.new()
	ray.position.y = 0.85
	ray.target_position = Vector3(0.0, 0.0, -3.0)
	ray.collision_mask = 31
	rigid.add_child(ray)
	holder.interaction_ray_cast = ray
	_world.add_entity(holder)
	rigid.global_position = Vector3(0.0, 0.0, -2.0)
	rigid.rotation.y = PI
	(holder.get_component(C_Strength) as C_Strength).value = 5.0
	(holder.get_component(C_Health) as C_Health).current = 100.0
	return holder
#endregion


#region Free contact preserves damage
func test_light_free_box_damages_stationary_native_npc() -> void:
	var result: Dictionary = await _measure_free_impact(2.0, 30.0)
	assert_true(bool(result.contact_seen), "The native collider must actually contact this NPC")
	assert_lt(_health.current, 100.0, "Stationary NPC receives damage through S_Impact/O_Damage")
	assert_lte(float(result.peak_planar_speed), 3.0 + POSITION_EPSILON)
	assert_lte(float(result.maximum_displacement), 1.0)


func test_heavy_free_body_damages_stationary_native_npc() -> void:
	var result: Dictionary = await _measure_free_impact(80.0, 20.0)
	assert_true(bool(result.contact_seen), "The native collider must actually contact this NPC")
	assert_lt(_health.current, 100.0, "Motion limits must not suppress actual heavy-contact damage")
	assert_lte(float(result.peak_planar_speed), 3.0 + POSITION_EPSILON)
	assert_lte(float(result.maximum_displacement), 1.0)


func test_authored_free_barrel_damages_stationary_native_npc() -> void:
	var barrel: E_GrabbableBody = _spawn_barrel()
	var projectile: RigidBody3D = barrel as Node as RigidBody3D
	projectile.gravity_scale = 0.0
	projectile.linear_damp = 0.0
	projectile.angular_damp = 0.0
	var result: Dictionary = await _sample_projectile(projectile, 20.0)
	assert_true(bool(result.contact_seen), "The authored barrel must actually hit the NPC")
	assert_lt(_health.current, 100.0)
	assert_lte(float(result.peak_planar_speed), 3.0 + POSITION_EPSILON)
	assert_lte(float(result.peak_upward_speed), 1.0 + POSITION_EPSILON)


func test_held_authored_barrel_press_records_native_contact_and_retains_grip() -> void:
	var holder: E_RigidBodyCharacter = _grip_holder()
	var barrel: E_GrabbableBody = _spawn_barrel()
	var projectile: RigidBody3D = barrel as Node as RigidBody3D
	projectile.global_position = Vector3(0.0, 0.85, -1.0)
	await _tick()
	holder.interaction_ray_cast.force_raycast_update()
	assert_true(GrabService.try_pickup(holder, barrel, C_Grabbable.HoldSlot.CARRY))
	var grip: Relationship = GrabQueries.held_relationship(barrel)
	assert_not_null(grip)
	if grip == null:
		return
	var origin: Vector3 = _body.global_position
	var peak_speed: float = 0.0
	var maximum_displacement: float = 0.0
	var contact_seen: bool = false
	for frame: int in SAMPLE_FRAMES:
		if frame < 30:
			holder.hold_anchor.position.z -= 1.5 * DELTA
		var contacts: Array[PhysicsContact] = await _tick()
		peak_speed = maxf(peak_speed, Vector2(_body.velocity.x, _body.velocity.z).length())
		maximum_displacement = maxf(maximum_displacement, _body.global_position.distance_to(origin))
		for contact: PhysicsContact in contacts:
			if contact.body_a == projectile or contact.body_b == projectile:
				contact_seen = true
	var retained: bool = GrabQueries.held_relationship(barrel) == grip
	print(
		"NATIVE_NPC_HELD_PROBE "
		+ JSON.stringify(
			{
				"native_body": _body.get_class(),
				"mass": projectile.mass,
				"frames": SAMPLE_FRAMES,
				"contact_seen": contact_seen,
				"grip_retained": retained,
				"health": _health.current,
				"peak_planar_speed": peak_speed,
				"maximum_displacement": maximum_displacement,
			}
		)
	)
	assert_true(contact_seen)
	assert_true(retained, "The press uses the real grip, without teleporting the held body")
	assert_lte(peak_speed, POSITION_EPSILON, "Held contact does not enqueue knockback")
	assert_lte(maximum_displacement, 0.1, "Sustained spring pressure cannot move native recovery")


func test_heavy_contact_against_native_wall_stays_inside_collision_boundary() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(6.0, 4.0, 0.4)
	wall.add_child(_collider(shape))
	wall.position = Vector3(0.0, 2.0, 1.0)
	_world.add_child(wall)
	await _tick()
	var result: Dictionary = await _measure_free_impact(80.0, 20.0)
	assert_true(bool(result.contact_seen))
	result = await _measure_free_impact(80.0, 20.0, wall)
	assert_true(bool(result.contact_seen))
	assert_true(bool(result.obstacle_seen), "A real wall contact is required")
	assert_lte(
		_body.global_position.z,
		0.52 + POSITION_EPSILON,
		"The actual capsule stays before the native wall",
	)
	var before: Vector3 = _body.global_position
	wall.free()
	var released_peak: float = 0.0
	for frame: int in 60:
		await _tick()
		released_peak = maxf(released_peak, _body.velocity.length())
	print(
		"NATIVE_NPC_WALL_PROBE "
		+ JSON.stringify(
			{
				"before_removal": before,
				"after_removal": _body.global_position,
				"peak_after_removal": released_peak,
				"release_frames": 60,
			}
		)
	)
	assert_lte(released_peak, POSITION_EPSILON, "Blocked reaction cannot launch after wall removal")


func test_held_barrel_support_records_lift_and_real_release() -> void:
	var holder: E_RigidBodyCharacter = _grip_holder()
	var barrel: E_GrabbableBody = _spawn_barrel()
	var support: RigidBody3D = barrel as Node as RigidBody3D
	support.global_position = Vector3(0.0, 0.85, -1.0)
	await _tick()
	holder.interaction_ray_cast.force_raycast_update()
	assert_true(GrabService.try_pickup(holder, barrel, C_Grabbable.HoldSlot.CARRY))
	var grip: Relationship = GrabQueries.held_relationship(barrel)
	assert_not_null(grip)
	if grip == null:
		return
	for frame: int in 12:
		await _tick()
	_body.global_position = support.global_position + Vector3.UP * 0.52
	_body.velocity = Vector3.ZERO
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	var support_seen: bool = false
	for frame: int in 24:
		await _tick()
		support_seen = support_seen or motion.floor_body_rid == support.get_rid()
	var origin: Vector3 = _body.global_position
	var peak_upward: float = 0.0
	var height_gain: float = 0.0
	for frame: int in 60:
		holder.hold_anchor.position.y += 0.6 * DELTA
		await _tick()
		support_seen = support_seen or motion.floor_body_rid == support.get_rid()
		peak_upward = maxf(peak_upward, _body.velocity.y)
		height_gain = maxf(height_gain, _body.global_position.y - origin.y)
	var retained: bool = GrabQueries.held_relationship(barrel) == grip
	GrabReleaseService.release(holder, barrel)
	var released: bool = GrabQueries.held_relationship(barrel) == null
	var released_upward: float = 0.0
	for frame: int in 30:
		await _tick()
		released_upward = maxf(released_upward, _body.velocity.y)
	print(
		"NATIVE_NPC_SUPPORT_PROBE "
		+ JSON.stringify(
			{
				"native_body": _body.get_class(),
				"support_seen": support_seen,
				"grip_retained_before_release": retained,
				"released": released,
				"peak_upward_speed": peak_upward,
				"height_gain": height_gain,
				"peak_after_release": released_upward,
			}
		)
	)
	assert_true(support_seen, "The actual native floor contact must belong to the held barrel")
	assert_true(retained)
	assert_true(released)
	assert_lte(peak_upward, 1.0 + POSITION_EPSILON)
	assert_lte(released_upward, 1.0 + POSITION_EPSILON)
#endregion


#region Aggregate response and independent locomotion
func test_aggregate_impulse_and_rebound_share_one_physical_limit() -> void:
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	var config: C_CharacterBody = _npc.get_component(C_CharacterBody) as C_CharacterBody
	config.impulse_velocity = Vector3.RIGHT * 2.0
	_body.velocity = config.impulse_velocity
	motion.pending_impulse = Vector3(100.0, 100.0, 100.0) * config.mass_kg
	config.pending_rebound_velocity = Vector3(100.0, 100.0, 100.0)
	await _tick()
	assert_lte(Vector2(config.impulse_velocity.x, config.impulse_velocity.z).length(), 3.0)
	assert_lte(config.impulse_velocity.y, 1.0)
	assert_eq(motion.pending_impulse, Vector3.ZERO)
	assert_eq(config.pending_rebound_velocity, Vector3.ZERO)
	for frame: int in 30:
		await _tick()
	assert_almost_eq(config.impulse_velocity.length(), 0.0, POSITION_EPSILON)


func test_own_fast_motion_and_independent_look_are_not_knockback_limited() -> void:
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	var control: C_Controller = _npc.get_component(C_Controller) as C_Controller
	motion.max_speed = 12.0
	control.direction_motion = Vector3.RIGHT
	control.direction_look = Vector3.FORWARD
	for frame: int in 40:
		await _tick()
	assert_gt(
		_body.velocity.x,
		10.0,
		"The external cap must not replace the authored walking speed",
	)
	assert_gt(-_npc.head_axis_y.global_basis.z.dot(Vector3.FORWARD), 0.95)
	assert_eq(control.direction_look, Vector3.FORWARD)


func test_native_corner_dissipates_repeated_blocked_external_motion() -> void:
	var walls: Array[StaticBody3D] = []
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var wall: StaticBody3D = StaticBody3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(0.4, 4.0, 6.0) if axis == Vector3.RIGHT else Vector3(6.0, 4.0, 0.4)
		wall.add_child(_collider(shape))
		wall.position = axis + Vector3.UP * 2.0
		_world.add_child(wall)
		walls.append(wall)
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	var config: C_CharacterBody = _npc.get_component(C_CharacterBody) as C_CharacterBody
	for frame: int in 90:
		motion.pending_impulse = Vector3(100.0, 0.0, 100.0) * config.mass_kg
		await _tick()
		assert_lte(_body.position.x, 0.52 + POSITION_EPSILON)
		assert_lte(_body.position.z, 0.52 + POSITION_EPSILON)
	assert_true(config.contact_bodies.has(walls[0].get_instance_id()))
	assert_true(config.contact_bodies.has(walls[1].get_instance_id()))
	var stopped: Vector3 = _body.position
	for wall: StaticBody3D in walls:
		wall.free()
	for frame: int in 30:
		await _tick()
	assert_lt(_body.position.distance_to(stopped), 0.01, "No stored corner launch")


func test_native_ceiling_blocks_upward_response_without_delayed_launch() -> void:
	var ceiling: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(6.0, 1.0, 6.0)
	ceiling.add_child(_collider(shape))
	ceiling.position = Vector3(0.0, 2.22, 0.0)
	_world.add_child(ceiling)
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	var config: C_CharacterBody = _npc.get_component(C_CharacterBody) as C_CharacterBody
	var touched: bool = false
	for frame: int in 30:
		motion.pending_impulse = Vector3.UP * 100.0 * config.mass_kg
		await _tick()
		touched = touched or config.contact_bodies.has(ceiling.get_instance_id())
		assert_lte(
			_body.position.y,
			0.04 + POSITION_EPSILON,
			"The actual capsule stays below the ceiling",
		)
	assert_true(touched)
	ceiling.free()
	var peak: float = 0.0
	for frame: int in 30:
		await _tick()
		peak = maxf(peak, _body.velocity.y)
	assert_lte(peak, POSITION_EPSILON)
#endregion


#region Scriptless held-body adapter
func test_scriptless_held_press_and_real_release_share_native_constraints() -> void:
	_world.add_system(S_Grab.new())
	var holder: E_RigidBodyCharacter = _grip_holder()
	var body: RigidBody3D = RigidBody3D.new()
	body.mass = 18.0
	body.gravity_scale = 0.0
	body.collision_layer = 4
	body.collision_mask = 3
	body.continuous_cd = true
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.7
	body.add_child(_collider(shape))
	_world.add_child(body)
	body.position = Vector3(0.0, 0.85, -1.0)
	var original_reports: int = body.max_contacts_reported
	var handle: Entity = PhysicsGrabTarget.handle_for(body, true)
	await _tick()
	holder.interaction_ray_cast.force_raycast_update()
	assert_true(GrabService.try_pickup(holder, handle, C_Grabbable.HoldSlot.CARRY))
	var grip: Relationship = GrabQueries.held_relationship(handle)
	assert_not_null(grip)
	if grip == null:
		return
	assert_same(GrabQueries.held_body_relationship(body), grip)
	var origin: Vector3 = _body.global_position
	var displacement: float = 0.0
	var config: C_CharacterBody = _npc.get_component(C_CharacterBody) as C_CharacterBody
	for frame: int in 120:
		if frame < 30:
			holder.hold_anchor.position.z -= 1.5 * DELTA
		await _tick()
		displacement = maxf(displacement, _body.global_position.distance_to(origin))
		assert_almost_eq(config.impulse_velocity.length(), 0.0, POSITION_EPSILON)
	assert_same(GrabQueries.held_relationship(handle), grip)
	assert_lt(displacement, 0.1, "Generic Carry cannot drive native overlap recovery")
	GrabReleaseService.release(holder, handle)
	assert_null(GrabQueries.held_body_relationship(body))
	assert_eq(body.max_contacts_reported, original_reports)

	# A new free contact episode follows real release and separation, without a fake throw context.
	body.position = Vector3(0.0, 0.85, -3.0)
	body.linear_velocity = Vector3.ZERO
	for frame: int in 4:
		await _tick()
	var result: Dictionary = await _sample_projectile(body, 20.0)
	assert_true(bool(result.contact_seen))
	assert_lt(_health.current, 100.0)
	assert_lte(float(result.peak_planar_speed), 3.0 + POSITION_EPSILON)
#endregion


#region Real throw attribution and ordinary platform support
func test_real_throw_keeps_actor_attribution_and_single_bounded_native_hit() -> void:
	var recorder: DamageRecorder = DamageRecorder.new()
	_world.add_observer(recorder)
	var holder: E_RigidBodyCharacter = _grip_holder()
	var barrel: E_GrabbableBody = BARREL_SCENE.instantiate() as E_GrabbableBody
	# Explicit fixture capability exercises the existing throw attribution operation.
	# The authored barrel asset and its ordinary slow throw balance are unchanged.
	barrel.component_resources.append(C_ThrowDamage.new())
	EntityCompositionFixture.register(_world, barrel)
	(barrel.get_component(C_Grabbable) as C_Grabbable).throw_velocity = 20.0
	var body: RigidBody3D = barrel as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.position = Vector3(0.0, 0.85, -1.0)
	await _tick()
	holder.interaction_ray_cast.force_raycast_update()
	assert_true(GrabService.try_pickup(holder, barrel, C_Grabbable.HoldSlot.CARRY))
	GrabService.throw_in_direction(holder, barrel, Vector3.BACK)
	assert_null(GrabQueries.held_relationship(barrel))
	assert_not_null(ThrowContext.relationship(barrel))
	var peak: float = 0.0
	for frame: int in 90:
		await _tick()
		peak = maxf(peak, Vector2(_body.velocity.x, _body.velocity.z).length())
	var hits: int = 0
	for result: DamageResult in recorder.results:
		if result.request.target != _npc:
			continue
		hits += 1
		assert_same(result.request.source, barrel)
		assert_same(result.request.instigator, holder)
		assert_eq(result.request.instigator_id, holder.id)
		assert_eq(result.request.damage_type, DamageRequest.Type.IMPACT)
	assert_eq(hits, 1)
	assert_lt(_health.current, 100.0)
	assert_null(ThrowContext.relationship(barrel))
	assert_lte(peak, 3.0 + POSITION_EPSILON)


func test_unheld_native_platform_still_transports_the_npc() -> void:
	var platform: RigidBody3D = RigidBody3D.new()
	platform.mass = 100.0
	platform.gravity_scale = 0.0
	platform.linear_damp = 0.0
	platform.axis_lock_angular_x = true
	platform.axis_lock_angular_z = true
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.0
	platform.physics_material_override = material
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.0, 0.4, 3.0)
	platform.add_child(_collider(shape))
	_world.add_child(platform)
	platform.position = Vector3(0.0, 0.2, 0.0)
	_body.position = Vector3(0.0, 0.41, 0.0)
	_npc.clear_physical_motion(true)
	for frame: int in 12:
		await _tick()
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	assert_eq(motion.floor_body_rid, platform.get_rid())
	platform.linear_velocity = Vector3.RIGHT
	var start: Vector3 = _body.position
	for frame: int in 36:
		await _tick()
	assert_gt(_body.position.x - start.x, 0.25, "A real unheld platform retains native transport")
	assert_eq(motion.floor_body_rid, platform.get_rid())
	assert_almost_eq(
		(_npc.get_component(C_CharacterBody) as C_CharacterBody).impulse_velocity.length(),
		0.0,
		POSITION_EPSILON,
	)
#endregion


#region Terrain and native physics delta
func test_native_npc_traverses_an_authored_height_step() -> void:
	var step_body: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(6.0, 0.15, 3.0)
	step_body.add_child(_collider(shape))
	step_body.position = Vector3(0.0, 0.075, -2.0)
	_world.add_child(step_body)
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	motion.max_speed = 2.0
	(_npc.get_component(C_Controller) as C_Controller).direction_motion = Vector3.FORWARD
	for frame: int in 90:
		await _tick()
	assert_lt(_body.position.z, -1.0)
	assert_gt(_body.position.y, 0.12, "The NPC capsule actually reaches the raised surface")
	assert_eq(motion.floor_body_rid, step_body.get_rid())
	assert_eq(_health.current, 100.0)


func test_native_npc_retains_floor_support_on_a_walkable_slope() -> void:
	var slope: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(6.0, 0.2, 3.0)
	slope.add_child(_collider(shape))
	slope.position = Vector3(0.0, 0.4, -2.0)
	slope.rotation.x = deg_to_rad(18.0)
	_world.add_child(slope)
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	motion.max_speed = 2.0
	(_npc.get_component(C_Controller) as C_Controller).direction_motion = Vector3.FORWARD
	for frame: int in 72:
		await _tick()
	assert_lt(_body.position.z, -1.0)
	assert_gt(_body.position.y, 0.3)
	assert_eq(motion.floor_body_rid, slope.get_rid())
	assert_gt(motion.floor_normal.y, 0.9)
	assert_lt(motion.floor_normal.y, 0.99)
	assert_eq(_health.current, 100.0)


## Native oblique contacts cannot convert bounded external motion into an untracked launch.
func test_oblique_contacts_preserve_external_caps_and_decay_without_controlled_residue() -> void:
	var slope: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(12.0, 0.5, 8.0)
	slope.add_child(_collider(shape))
	slope.position = Vector3(0.0, 0.8, 0.0)
	slope.rotation.z = deg_to_rad(45.0)
	_world.add_child(slope)
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	var config: C_CharacterBody = _npc.get_component(C_CharacterBody) as C_CharacterBody
	motion.floor_max_angle_degrees = 60.0
	motion.ground_deceleration = 0.0
	motion.air_acceleration = 0.0
	config.gravity_scale = 0.0
	config.step_height = 0.0
	for incoming: Vector3 in [Vector3.RIGHT * 30.0, Vector3.DOWN * 30.0]:
		_npc.clear_physical_motion(true)
		_body.global_position = Vector3(0.0, 1.2, 0.0)
		var contacted: bool = false
		for frame: int in 20:
			motion.pending_impulse = incoming * config.mass_kg
			await _tick()
			contacted = contacted or config.contact_bodies.has(slope.get_instance_id())
			assert_lte(config.impulse_velocity.y, 1.0 + POSITION_EPSILON)
			assert_lte(
				Vector2(config.impulse_velocity.x, config.impulse_velocity.z).length(),
				3.0 + POSITION_EPSILON,
			)
			assert_lte(_body.velocity.y, 1.0 + POSITION_EPSILON)
			assert_lte(Vector2(_body.velocity.x, _body.velocity.z).length(), 3.0 + POSITION_EPSILON)
		assert_true(contacted, "The actual native oblique collider must participate")
		for frame: int in 45:
			await _tick()
		assert_almost_eq(config.impulse_velocity.length(), 0.0, POSITION_EPSILON)
		assert_almost_eq(
			_body.velocity.length(),
			0.0,
			POSITION_EPSILON,
			"No converted response remains as own locomotion",
		)


## Native wall blocking may stop motion; release must recover own speed without a stored launch.
func test_oblique_wall_resolves_mixed_motion_and_gravity_without_delayed_launch() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.4, 12.0, 20.0)
	wall.add_child(_collider(shape))
	wall.position = Vector3(0.75, 1.0, 0.0)
	wall.rotation.z = deg_to_rad(20.0)
	_world.add_child(wall)
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	var config: C_CharacterBody = _npc.get_component(C_CharacterBody) as C_CharacterBody
	var control: C_Controller = _npc.get_component(C_Controller) as C_Controller
	motion.max_speed = 8.0
	motion.ground_deceleration = 0.0
	control.direction_motion = Vector3.FORWARD
	_body.velocity = Vector3.FORWARD * 8.0
	var contacted: bool = false
	for frame: int in 24:
		motion.pending_impulse = Vector3(30.0, 30.0, 0.0) * config.mass_kg
		await _tick()
		contacted = contacted or config.contact_bodies.has(wall.get_instance_id())
		assert_lte(config.impulse_velocity.y, 1.0 + POSITION_EPSILON)
		assert_lte(
			Vector2(config.impulse_velocity.x, config.impulse_velocity.z).length(),
			3.0 + POSITION_EPSILON,
		)
		assert_lte(_body.velocity.y, 1.0 + POSITION_EPSILON)
		assert_lte(_body.velocity.z, POSITION_EPSILON, "The wall cannot reverse own motion")
	assert_true(contacted, "The tilted collider must be a native wall contact")
	wall.free()
	for frame: int in 45:
		await _tick()
	assert_almost_eq(config.impulse_velocity.length(), 0.0, POSITION_EPSILON)
	assert_almost_eq(_body.velocity.x, 0.0, POSITION_EPSILON, "No delayed wall launch")
	assert_lt(_body.velocity.z, -7.9)
	assert_lte(_body.velocity.y, 0.0)


func test_external_decay_uses_native_delta_at_60_and_120_physics_hz() -> void:
	var motion: C_Motion = _npc.get_component(C_Motion) as C_Motion
	var config: C_CharacterBody = _npc.get_component(C_CharacterBody) as C_CharacterBody
	var samples: Array[Dictionary] = []
	for rate: int in [60, 120]:
		Engine.physics_ticks_per_second = rate
		for frame: int in 3:
			await _tick()
		_npc.clear_physical_motion(true)
		motion.pending_impulse = Vector3.RIGHT * 3.0 * config.mass_kg
		var start_tick: int = Engine.get_physics_frames()
		var requested_ticks: int = rate / 10
		while Engine.get_physics_frames() - start_tick < requested_ticks:
			await _tick()
		var steps: int = Engine.get_physics_frames() - start_tick
		var elapsed: float = float(steps) / float(rate)
		var expected: float = maxf(0.0, 3.0 - 10.0 * elapsed)
		assert_almost_eq(config.impulse_velocity.x, expected, 0.02)
		samples.append(
			{
				"physics_hz": rate,
				"actual_steps": steps,
				"elapsed": elapsed,
				"external_speed": config.impulse_velocity.x,
			}
		)
	Engine.physics_ticks_per_second = _original_physics_rate
	print("NATIVE_NPC_DELTA_PROBE " + JSON.stringify(samples))
#endregion
