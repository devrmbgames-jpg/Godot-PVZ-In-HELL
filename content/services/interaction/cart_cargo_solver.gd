extends RefCounted
## Velocity-only restraint for cargo. Runs only from the cargo RigidBody physics callback.
class_name CartCargoSolver

const MAX_ANGULAR_SPEED: float = 6.0
const ROTATION_EPSILON: float = 0.0001


static func integrate(cargo: Entity, state: PhysicsDirectBodyState3D) -> bool:
	var binding: Relationship = CartCargoService.relationship(cargo)
	if binding == null:
		return false
	var cart: Entity = binding.target as Entity
	var data: R_CartCargo = binding.relation as R_CartCargo
	if not S_Grab.entity_available(cart) or not S_Grab.entity_available(cargo):
		CartCargoService.release(cargo)
		return false
	if S_Grab.held_relationship(cargo) != null or _destroyed(cargo):
		CartCargoService.release(cargo)
		return false

	var cart_body: Node3D = cart as Node as Node3D
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if cart_body == null or config == null or data == null:
		CartCargoService.release(cargo)
		return false

	var desired: Transform3D = cart_body.global_transform * data.local_pose
	var offset: Vector3 = desired.origin - state.transform.origin
	if offset.length() > config.cargo_break_distance:
		CartCargoService.release(cargo)
		return false

	state.linear_velocity = (offset / state.step).limit_length(config.cargo_follow_speed)
	var rotation_error: Quaternion = (
		desired.basis.get_rotation_quaternion()
		* state.transform.basis.get_rotation_quaternion().inverse()
	).normalized()
	if rotation_error.w < 0.0:
		rotation_error = -rotation_error
	var angle: float = rotation_error.get_angle()
	state.angular_velocity = Vector3.ZERO
	if angle > ROTATION_EPSILON:
		state.angular_velocity = rotation_error.get_axis() * minf(
			angle / state.step,
			MAX_ANGULAR_SPEED,
		)
	return true


static func _destroyed(cargo: Entity) -> bool:
	var state: C_PackageState = cargo.get_component(C_PackageState) as C_PackageState
	return state != null and state.damage == C_PackageState.Damage.DESTROYED
