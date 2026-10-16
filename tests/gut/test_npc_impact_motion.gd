extends GutTest
## Native stationary NPC contact damage and measured motion before the CharacterBody migration.

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
var _body: RigidBody3D
var _health: C_Health


#region Native contact fixture
func before_each() -> void:
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
	_body = _npc as Node as RigidBody3D
	_body.global_position = Vector3(0.0, 0.02, 0.0)
	_health = _npc.get_component(C_Health) as C_Health
	_health.value = 100.0
	_health.current = 100.0
	for frame: int in 12:
		await _tick()
	_health.current = 100.0


func after_each() -> void:
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
	var inbox: C_ImpactInbox = _npc.get_component(C_ImpactInbox) as C_ImpactInbox
	var contacts: Array[PhysicsContact] = inbox.contacts.duplicate()
	_world.process(DELTA)
	return contacts


func _measure_free_impact(projectile_mass: float, projectile_speed: float) -> Dictionary:
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
	return await _sample_projectile(projectile, projectile_speed)


func _sample_projectile(projectile: RigidBody3D, projectile_speed: float) -> Dictionary:
	projectile.global_position = Vector3(0.0, 0.85, -3.0)
	projectile.linear_velocity = Vector3(0.0, 0.0, projectile_speed)
	var origin: Vector3 = _body.global_position
	var peak_speed: float = 0.0
	var peak_upward: float = 0.0
	var maximum_height: float = origin.y
	var maximum_displacement: float = 0.0
	var contact_seen: bool = false
	for frame: int in SAMPLE_FRAMES:
		var contacts: Array[PhysicsContact] = await _tick()
		peak_speed = maxf(
			peak_speed,
			Vector2(_body.linear_velocity.x, _body.linear_velocity.z).length(),
		)
		peak_upward = maxf(peak_upward, _body.linear_velocity.y)
		maximum_height = maxf(maximum_height, _body.global_position.y)
		maximum_displacement = maxf(maximum_displacement, _body.global_position.distance_to(origin))
		for contact: PhysicsContact in contacts:
			if contact.body_b == projectile or contact.body_a == projectile:
				contact_seen = true
	var result: Dictionary = {
		"native_body": _body.get_class(),
		"npc_mass": _body.mass,
		"projectile_mass": projectile.mass,
		"projectile_speed": projectile_speed,
		"contact_seen": contact_seen,
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


func test_heavy_free_body_damages_stationary_native_npc() -> void:
	var result: Dictionary = await _measure_free_impact(80.0, 20.0)
	assert_true(bool(result.contact_seen), "The native collider must actually contact this NPC")
	assert_lt(_health.current, 100.0, "Motion limits must not suppress actual heavy-contact damage")


func test_authored_free_barrel_damages_stationary_native_npc() -> void:
	var barrel: E_GrabbableBody = _spawn_barrel()
	var projectile: RigidBody3D = barrel as Node as RigidBody3D
	projectile.gravity_scale = 0.0
	projectile.linear_damp = 0.0
	projectile.angular_damp = 0.0
	var result: Dictionary = await _sample_projectile(projectile, 20.0)
	assert_true(bool(result.contact_seen), "The authored barrel must actually hit the NPC")
	assert_lt(_health.current, 100.0)


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
		holder.hold_anchor.position.z -= 1.5 * DELTA
		var contacts: Array[PhysicsContact] = await _tick()
		peak_speed = maxf(
			peak_speed,
			Vector2(_body.linear_velocity.x, _body.linear_velocity.z).length(),
		)
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
		released_peak = maxf(released_peak, _body.linear_velocity.length())
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
	_body.linear_velocity = Vector3.ZERO
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
		peak_upward = maxf(peak_upward, _body.linear_velocity.y)
		height_gain = maxf(height_gain, _body.global_position.y - origin.y)
	var retained: bool = GrabQueries.held_relationship(barrel) == grip
	GrabReleaseService.release(holder, barrel)
	var released: bool = GrabQueries.held_relationship(barrel) == null
	var released_upward: float = 0.0
	for frame: int in 30:
		await _tick()
		released_upward = maxf(released_upward, _body.linear_velocity.y)
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
#endregion
