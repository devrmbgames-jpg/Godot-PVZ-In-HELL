extends RefCounted
## Push actor-follow RigidBody solver. Runs only from the actor physics callback.
class_name PushActorSolver


static func integrate(actor: Entity, state: PhysicsDirectBodyState3D) -> bool:
	var cart: Entity = PushService.pushed_object(actor)
	if cart == null or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.PUSH:
		return false
	if not PushService.valid_pair(actor, cart):
		PushService.end(actor, cart)
		return false
	if state.step <= 0.0:
		return true

	var config: C_Pushable = cart.get_component(C_Pushable) as C_Pushable
	var body: RigidBody3D = cart as Node as RigidBody3D
	var handle_position: Vector3 = (
		body.global_position - PushService.forward(cart) * config.handle_distance
	)
	var correction: Vector3 = handle_position - state.transform.origin
	correction.y = 0.0
	var correction_speed: Vector3 = (correction / state.step).limit_length(config.follow_speed)
	var desired: Vector3 = (body.linear_velocity + correction_speed).limit_length(
		config.forward_speed + config.follow_speed
	)
	state.linear_velocity = Vector3(desired.x, state.linear_velocity.y, desired.z)
	return true
