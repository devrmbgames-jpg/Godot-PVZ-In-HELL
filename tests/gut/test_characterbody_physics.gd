extends GutTest
## Actual native player contacts; damage still travels through S_Impact and O_Damage.

const MAIN: PackedScene = preload("res://content/scenes/main_level.tscn")
const DELTA: float = 1.0 / 60.0
const MAX_CONTACT_FRAMES: int = 180

var _world: World
var _player: E_CharacterBodyPlayer
var _body: CharacterBody3D
var _health: C_Health
var _floor: StaticBody3D


func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_Damage.new())
	_world.add_system(S_Impact.new())
	_floor = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(30.0, 0.5, 30.0)
	_floor.add_child(_collider(shape))
	_floor.position.y = -0.25
	_world.add_child(_floor)
	var host: Node3D = MAIN.instantiate() as Node3D
	_player = host.get_node("Entityes/Player") as E_CharacterBodyPlayer
	_player.get_parent().remove_child(_player)
	host.free()
	_world.add_entity(_player)
	for child: Node in (_player as Node).find_children("*", "Entity", true, false):
		_world.add_entity(child as Entity, null, false)
	_body = _player as Node as CharacterBody3D
	_body.global_position = Vector3(0.0, 0.01, 0.0)
	_health = _player.get_component(C_Health) as C_Health
	_health.value = 100.0
	_health.current = 100.0
	for frame: int in 12:
		await _tick()


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	await get_tree().process_frame


func _tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	_world.process(DELTA)


func _collider(shape: Shape3D) -> CollisionShape3D:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	return collision


func test_big_fall_damages_and_bounces_then_rearms_after_separation() -> void:
	for fall: int in 2:
		var previous_hp: float = _health.current
		_body.global_position = Vector3(0.0, 8.0, 0.0)
		_body.velocity = Vector3.ZERO
		var bounced: bool = false
		for frame: int in MAX_CONTACT_FRAMES:
			await _tick()
			if _health.current < previous_hp and _body.velocity.y > 1.0:
				bounced = true
				break
		assert_true(bounced, "Fall %d causes real damage and upward rebound" % fall)
		assert_almost_eq(_health.current, previous_hp - 25.0, 0.01, "Living impact cap still applies")
		for frame: int in 65:
			await _tick()
		assert_almost_eq(_health.current, previous_hp - 25.0, 0.01, "Resting floor contact does not repeatedly damage")


func test_ground_ray_gently_pushes_real_rigid_support() -> void:
	var support: RigidBody3D = RigidBody3D.new()
	support.mass = 10.0
	support.gravity_scale = 0.0
	support.linear_damp = 0.0
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = 0.0
	support.physics_material_override = material
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.0, 0.4, 3.0)
	support.add_child(_collider(shape))
	_world.add_child(support)
	support.global_position = Vector3(0.0, 0.2, 0.0)
	_body.global_position = Vector3(0.0, 0.41, 0.0)
	_body.velocity = Vector3.ZERO
	for frame: int in 12:
		await _tick()
	var control: C_Controller = _player.get_component(C_Controller) as C_Controller
	control.direction_motion = Vector3.RIGHT
	for frame: int in 8:
		await _tick()
	assert_gt(support.linear_velocity.x, 0.001, "Support receives a small horizontal impulse through Ground")
	assert_lt(support.linear_velocity.x, 1.0, "Walking support response stays bounded")
	assert_eq(_health.current, 100.0)


func test_fast_rigid_hit_damages_and_knocks_back_native_player() -> void:
	var projectile: RigidBody3D = RigidBody3D.new()
	projectile.mass = 10.0
	projectile.gravity_scale = 0.0
	projectile.linear_damp = 0.0
	projectile.continuous_cd = true
	projectile.set_script(load("res://content/entities/characters/e_rigid_body_character.gd"))
	var entity: Entity = projectile as Node as Entity
	entity.component_resources = [C_RigidBody.new()]
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.25
	projectile.add_child(_collider(shape))
	_world.add_entity(entity)
	projectile.global_position = Vector3(0.0, 0.8, -2.0)
	projectile.linear_velocity = Vector3(0.0, 0.0, 20.0)
	var knocked: bool = false
	var highest_speed: float = 0.0
	var highest_impulse: float = 0.0
	var player_speed: float = 0.0
	for frame: int in 45:
		await get_tree().physics_frame
		await get_tree().process_frame
		for participant: Entity in [_player, entity]:
			var inbox: C_ImpactInbox = participant.get_component(C_ImpactInbox) as C_ImpactInbox
			for contact: PhysicsContact in inbox.contacts:
				highest_speed = maxf(highest_speed, contact.normal_speed)
				highest_impulse = maxf(highest_impulse, contact.normal_impulse)
		_world.process(DELTA)
		player_speed = maxf(player_speed, _body.velocity.z)
		if _health.current < 100.0 and _body.velocity.z > 1.0:
			knocked = true
			break
	assert_true(knocked, "Real rigid hit: HP=%s speed=%s impulse=%s player_vz=%s rigid_z=%s" % [_health.current, highest_speed, highest_impulse, player_speed, projectile.global_position.z])
	assert_gte(_health.current, 75.0, "One physical hit respects living damage cap")


func test_crouch_switches_native_shapes_and_shared_camera_height() -> void:
	_world.add_system(S_Crouch.new())
	_world.add_system(S_CrouchPresentation.new())
	var control: C_Controller = _player.get_component(C_Controller) as C_Controller
	var crouch: C_Crouch = _player.get_component(C_Crouch) as C_Crouch
	control.action_crouch = true
	for frame: int in 30:
		await _tick()
	assert_true(crouch.active)
	assert_true(_player.shape_standing.disabled)
	assert_false(_player.shape_crouching.disabled)
	assert_almost_eq(_player.camera_root.position.y, crouch.camera_height_crouching, 0.001)
	control.action_crouch = false
	for frame: int in 30:
		await _tick()
	assert_false(crouch.active)
	assert_false(_player.shape_standing.disabled)
	assert_true(_player.shape_crouching.disabled)


func test_cart_driver_follows_and_releases_when_out_of_range() -> void:
	var packed: PackedScene = load("res://content/entities/props/push_cart.tscn") as PackedScene
	var cart: Entity = packed.instantiate() as Entity
	_world.add_entity(cart)
	var cart_body: CharacterBody3D = cart as Node as CharacterBody3D
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	cart_body.global_position = Vector3(0.0, 0.85, -config.handle_distance)
	for frame: int in 12:
		await _tick()
	var control: C_Controller = _player.get_component(C_Controller) as C_Controller
	control.direction_look = (cart_body.global_position + Vector3.UP * 0.24 + Vector3.BACK * 0.79 - _player.interaction_ray_cast.global_position).normalized()
	for frame: int in 2:
		await _tick()
	assert_true(CartTransportService.can_begin(_player, cart), "Cart start actor=%s cart=%s reach=%s available=%s focus=%s" % [_body.global_position, cart_body.global_position, GrabService.within_pickup_reach(_player, cart), GrabService.holder_available(_player), InteractionControlFocus.current(_player)])
	CartTransportService.begin(_player, cart)
	assert_eq(CartTransportService.current(_player), cart)
	control.move_axis = Vector2(0.0, -1.0)
	for frame: int in 45:
		await _tick()
	assert_lt(_body.global_position.z, -0.5, "CharacterBody follows the real driven cart")
	var handle: Vector3 = CartTransportService.handle_position(cart_body, config)
	handle.y = _body.global_position.y
	assert_lt(_body.global_position.distance_to(handle), config.follow_tolerance)
	var step: StaticBody3D = StaticBody3D.new()
	var step_shape: BoxShape3D = BoxShape3D.new()
	step_shape.size = Vector3(6.0, 0.15, 6.0)
	step.add_child(_collider(step_shape))
	_world.add_child(step)
	step.global_position = Vector3(0.0, 0.075, -7.0)
	for frame: int in 180:
		await _tick()
	assert_eq(CartTransportService.current(_player), cart, "Driver keeps session through the authored small step")
	assert_lt(_body.global_position.z, -5.0, "Cart and player both traverse the step")
	assert_gt(_body.global_position.y, 0.12, "Driver stands on the raised support")
	_body.global_position.x += config.focus_distance + 1.0
	await _tick()
	assert_null(CartTransportService.current(_player), "Invalid session releases its relationship and focus")


func test_saved_rigid_player_record_restores_to_authored_characterbody_and_clears_motion() -> void:
	(_player as Node).owner = _world
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new()]
	_world.add_entity(session)
	session.owner = _world
	var snapshot: Dictionary = WorldSnapshotService.capture(_world, 2)
	for record: Dictionary in snapshot.entities:
		if record.entity_id == _player.id:
			record.scene = "res://content/entities/characters/e_rigid_body_character.tscn"
	var saved_pose: Transform3D = _body.global_transform
	_body.global_position += Vector3(3.0, 2.0, 1.0)
	_body.velocity = Vector3(5.0, 5.0, 5.0)
	var config: C_CharacterBody = _player.get_component(C_CharacterBody) as C_CharacterBody
	config.impulse_velocity = Vector3.RIGHT * 2.0
	config.pending_rebound_velocity = Vector3.UP * 4.0
	var motion: C_Motion = _player.get_component(C_Motion) as C_Motion
	motion.pending_impulse = Vector3.UP * 350.0
	assert_true(WorldSnapshotService.restore(snapshot, _world), "Old scene path binds to the existing authored player")
	assert_eq(_body.global_transform, saved_pose)
	assert_eq(_body.velocity, Vector3.ZERO)
	assert_eq(config.impulse_velocity, Vector3.ZERO)
	assert_eq(config.pending_rebound_velocity, Vector3.ZERO)
	assert_eq(motion.pending_impulse, Vector3.ZERO)
	assert_false(_player.has_component(C_RigidBody))
