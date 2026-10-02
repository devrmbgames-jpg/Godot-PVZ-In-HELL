extends RefCounted
## Native CharacterBody movement, immediate view and independent body-facing for belt access.
class_name KinematicCharacterSolver

const MINIMUM_MASS: float = 0.01
const MINIMUM_STEP: float = 0.0001
const TERRAIN_MASK: int = 1


static func step(
	actor: E_CharacterBodyPlayer, body: CharacterBody3D, control: C_Controller,
	motion: C_Motion, config: C_CharacterBody, delta: float,
) -> void:
	_update_view(actor, body, control, config, delta)
	var old_impulse: Vector3 = config.impulse_velocity
	var impulse: Vector3 = motion.pending_impulse / maxf(config.mass_kg, MINIMUM_MASS)
	motion.pending_impulse = Vector3.ZERO
	config.impulse_velocity += Vector3(impulse.x, 0.0, impulse.z)
	config.impulse_velocity = config.impulse_velocity.move_toward(Vector3.ZERO, config.impulse_decay_per_second * delta)
	var controlled: Vector3 = body.velocity - old_impulse
	controlled.y += impulse.y
	var rebound: Vector3 = config.pending_rebound_velocity
	config.pending_rebound_velocity = Vector3.ZERO
	controlled.y += rebound.y
	config.impulse_velocity += Vector3(rebound.x, 0.0, rebound.z)
	if body.is_on_floor() and controlled.y < 0.0:
		controlled.y = 0.0
	else:
		controlled += body.get_gravity() * config.gravity_scale * delta
	var desired: Vector3 = control.direction_motion.limit_length(1.0) if motion.control_enabled else Vector3.ZERO
	desired.y = 0.0
	var speed: float = CharacterMotionSolver.effective_speed(
		motion, actor.get_component(C_CarryLoad) as C_CarryLoad,
		actor.get_component(C_Strength) as C_Strength, actor.get_component(C_Hunger) as C_Hunger,
	)
	var planar: Vector3 = Vector3(controlled.x, 0.0, controlled.z)
	var acceleration: float = motion.ground_acceleration if not desired.is_zero_approx() else motion.ground_deceleration
	if not body.is_on_floor():
		acceleration = motion.air_acceleration
	planar = planar.move_toward(desired * speed, acceleration * delta)
	controlled.x = planar.x
	controlled.z = planar.z
	body.velocity = controlled + config.impulse_velocity
	var transport_step: float = _follow_transport(actor, body, delta)
	body.floor_snap_length = motion.floor_snap_distance
	body.floor_max_angle = deg_to_rad(motion.floor_max_angle_degrees)
	if config.impulse_velocity.is_zero_approx():
		_lift_step(body, maxf(config.step_height, transport_step), delta)
	var incoming: Vector3 = body.velocity
	body.move_and_slide()
	KinematicImpactCapture.capture(actor, body, config, incoming)
	motion.is_on_floor = body.is_on_floor()
	motion.floor_normal = body.get_floor_normal() if motion.is_on_floor else Vector3.UP
	motion.floor_velocity = body.get_platform_velocity() if motion.is_on_floor else Vector3.ZERO
	motion.floor_body_rid = RID()
	_push_support(actor, body, motion, config, delta)


static func _update_view(actor: E_PhysicalCharacter, body: CharacterBody3D, control: C_Controller, config: C_CharacterBody, delta: float) -> void:
	if actor.head_axis_y == null or actor.head_axis_x == null or control.direction_look.is_zero_approx():
		return
	var grab: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
	if grab != null and grab.rotation_active:
		return
	var look: C_Look = actor.get_component(C_Look) as C_Look
	if look == null:
		return
	var direction: Vector3 = control.direction_look.normalized()
	var yaw: float = atan2(-direction.x, -direction.z)
	var pitch: float = asin(clampf(direction.y, -1.0, 1.0))
	var relative: float = wrapf(yaw - body.rotation.y, -PI, PI)
	var limit: float = deg_to_rad(look.head_yaw_limit)
	# Looking down freezes the torso while the camera can reach both belt slots.
	if pitch > -deg_to_rad(config.slot_look_down_degrees):
		var target: float = body.rotation.y
		if not control.direction_motion.is_zero_approx():
			target = yaw
		elif absf(relative) > limit:
			target = yaw - signf(relative) * limit
		body.rotation.y = rotate_toward(body.rotation.y, target, deg_to_rad(look.motion_alignment_acceleration) * delta)
	actor.head_axis_y.rotation.y = wrapf(yaw - body.rotation.y, -PI, PI)
	actor.head_axis_x.rotation.x = pitch


static func _follow_transport(actor: Entity, body: CharacterBody3D, delta: float) -> float:
	var transport: Entity = CartTransportService.current(actor)
	if transport != null and InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.TRANSPORT:
		var cart: CharacterBody3D = transport as Node as CharacterBody3D
		var config: C_CartTransport = transport.get_component(C_CartTransport) as C_CartTransport
		if not CartTransportService.driver_valid(cart, config, actor):
			CartTransportService.end(transport)
			return 0.0
		var offset: Vector3 = CartTransportService.handle_position(cart, config) - body.global_position
		offset.y = 0.0
		var follow: Vector3 = (offset / maxf(delta, MINIMUM_STEP)).limit_length(config.follow_speed)
		body.velocity.x = follow.x
		body.velocity.z = follow.z
		return config.step_height
	var pushed: Entity = PushService.pushed_object(actor)
	if pushed != null and InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.PUSH:
		if not PushService.valid_pair(actor, pushed):
			PushService.end(actor, pushed)
			return 0.0
		var cart: RigidBody3D = pushed as Node as RigidBody3D
		var config: C_Pushable = pushed.get_component(C_Pushable) as C_Pushable
		var offset: Vector3 = cart.global_position - PushService.forward(pushed) * config.handle_distance - body.global_position
		offset.y = 0.0
		var follow: Vector3 = (cart.linear_velocity + (offset / maxf(delta, MINIMUM_STEP)).limit_length(config.follow_speed)).limit_length(config.forward_speed + config.follow_speed)
		body.velocity.x = follow.x
		body.velocity.z = follow.z
	return 0.0


## Native body checks the entire up/across/down route before lifting onto a small step.
## Normal move_and_slide still owns forward motion, floor contacts and impact reporting.
static func _lift_step(body: CharacterBody3D, height: float, delta: float) -> void:
	if height <= 0.0 or not body.is_on_floor() or body.velocity.y > 0.0:
		return
	var travel: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z) * delta
	if travel.is_zero_approx():
		return
	var obstruction: KinematicCollision3D = KinematicCollision3D.new()
	if not body.test_move(body.global_transform, travel, obstruction):
		return
	if obstruction.get_normal().y >= cos(body.floor_max_angle):
		return
	var support_probe: Vector3 = obstruction.get_position() + travel.normalized() * height + Vector3.UP * height
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(support_probe, support_probe - Vector3.UP * height * 2.0, TERRAIN_MASK, [body.get_rid()])
	var support: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
	if support.is_empty() or (support["normal"] as Vector3).y < cos(body.floor_max_angle):
		return
	var raised: Transform3D = body.global_transform
	var up: Vector3 = Vector3.UP * height
	if body.test_move(raised, up):
		return
	raised.origin += up
	if body.test_move(raised, travel):
		return
	raised.origin += travel
	var landing: KinematicCollision3D = KinematicCollision3D.new()
	if not body.test_move(raised, Vector3.DOWN * (height + body.floor_snap_length), landing):
		return
	if landing.get_normal().y < cos(body.floor_max_angle):
		return
	var rise: float = height + landing.get_travel().y
	if rise > body.safe_margin and rise <= height:
		body.move_and_collide(Vector3.UP * rise)


static func _push_support(actor: E_CharacterBodyPlayer, body: CharacterBody3D, motion: C_Motion, config: C_CharacterBody, delta: float) -> void:
	if actor.ground_ray == null or not motion.is_on_floor:
		return
	actor.ground_ray.force_raycast_update()
	if not actor.ground_ray.is_colliding():
		return
	var support: PhysicsBody3D = actor.ground_ray.get_collider() as PhysicsBody3D
	if support == null:
		return
	motion.floor_body_rid = support.get_rid()
	motion.floor_contact_position = actor.ground_ray.get_collision_point()
	var rigid: RigidBody3D = support as RigidBody3D
	if rigid == null or rigid.freeze:
		return
	var support_entity: Entity = rigid as Node as Entity
	var held: Relationship = GrabService.held_relationship(support_entity)
	if held != null and held.target == actor:
		return
	var planar: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z).limit_length(1.0)
	var impulse: Vector3 = (Vector3.DOWN + planar) * config.ground_impulse_per_second * delta
	impulse = impulse.limit_length(config.ground_maximum_velocity_change * rigid.mass)
	rigid.apply_impulse(impulse, motion.floor_contact_position - rigid.global_position)
