extends RefCounted
## RigidBody actor follow solver for an active transport session.
class_name CartDriverSolver

const MOTION_EPSILON: float = 0.0001
const COLLISION_MARGIN: float = 0.002
const TERRAIN_MASK: int = 1


static func integrate(actor: Entity, state: PhysicsDirectBodyState3D) -> bool:
	var cart: Entity = CartTransportService.current(actor)
	if (
		cart == null
		or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.TRANSPORT
	):
		return false
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	var body: CharacterBody3D = cart as Node as CharacterBody3D
	if not CartTransportService.driver_valid(body, config, actor):
		CartTransportService.end(cart)
		return false

	var correction: Vector3 = (
		CartTransportService.handle_position(body, config) - state.transform.origin
	)
	correction.y = 0.0
	var velocity: Vector3 = (
		correction / maxf(state.step, MOTION_EPSILON)
	).limit_length(config.follow_speed)
	state.linear_velocity = Vector3(velocity.x, minf(state.linear_velocity.y, 0.0), velocity.z)
	_lift_driver(actor, body, config, state)
	return true


static func _lift_driver(
	actor: Entity,
	body: CharacterBody3D,
	config: C_CartTransport,
	state: PhysicsDirectBodyState3D,
) -> void:
	var handle: Vector3 = CartTransportService.handle_position(body, config)
	handle.y = state.transform.origin.y + config.step_height + COLLISION_MARGIN
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		handle,
		handle - Vector3.UP * (config.step_height * 2.0),
		TERRAIN_MASK,
	)
	var actor_body: CollisionObject3D = actor as Node as CollisionObject3D
	if actor_body == null:
		return
	ray.exclude = [actor_body.get_rid(), body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return
	var floor_normal: Vector3 = hit["normal"] as Vector3
	var floor_point: Vector3 = hit["position"] as Vector3
	var rise: float = floor_point.y - state.transform.origin.y
	if floor_normal.y < cos(body.floor_max_angle) or rise <= COLLISION_MARGIN:
		return
	if rise > config.step_height:
		return
	state.linear_velocity.y = maxf(
		state.linear_velocity.y,
		minf(rise / state.step, config.follow_speed),
	)
