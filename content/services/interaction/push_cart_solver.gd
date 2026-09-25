extends RefCounted
## Push cart RigidBody solver. Runs only from the pushed body's physics callback.
class_name PushCartSolver


static func integrate(cart: Entity, state: PhysicsDirectBodyState3D) -> void:
	var binding: Relationship = PushService.relationship(cart)
	if binding == null:
		return
	var actor: Entity = binding.target as Entity
	if not PushService.valid_pair(actor, cart):
		PushService.end(actor, cart)
		return

	var desired_velocity: Vector3 = Vector3.ZERO
	var desired_turn: float = 0.0
	if InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.PUSH:
		var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
		var config: C_Pushable = cart.get_component(C_Pushable) as C_Pushable
		if controller.move_axis.y < -PushService.DIRECTION_EPSILON:
			desired_velocity = PushService.forward(cart) * config.forward_speed
		desired_turn = -signf(controller.move_axis.x) * config.turn_speed

	state.linear_velocity = Vector3(desired_velocity.x, state.linear_velocity.y, desired_velocity.z)
	state.angular_velocity = Vector3(0.0, desired_turn, 0.0)
