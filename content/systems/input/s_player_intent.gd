extends System
## Converts raw C_Controller input into gameplay-space look/motion for the active control mode.
class_name S_PlayerIntent

const LOOK_SENSITIVITY: float = 0.002
const MAX_LOOK_PITCH: float = deg_to_rad(89.0)


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_PlayerInput] }


func query() -> QueryBuilder:
	return q.with_all([C_Controller, C_PlayerInputController]).iterate([C_Controller])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var controllers: Array = components[0]
	for index: int in entities.size():
		_apply(entities[index], controllers[index] as C_Controller)


func _apply(entity: Entity, controller: C_Controller) -> void:
	if controller == null or not is_instance_valid(entity):
		return
	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(entity)
	var transport: Entity = CartTransportService.current(entity)
	var cart: Entity = PushService.pushed_object(entity)
	var driving: bool = transport != null and focus == InteractionControlFocus.Priority.TRANSPORT
	var pushing: bool = cart != null and focus == InteractionControlFocus.Priority.PUSH
	var rotating: bool = InteractionActionResolver.wants_rotation(entity, controller)

	if driving:
		var transport_node: Node3D = transport as Node as Node3D
		if transport_node != null:
			controller.direction_look = -transport_node.global_basis.z
		controller.look_delta = Vector2.ZERO
		controller.action_jump = false
		controller.action_crouch = false
	elif pushing:
		var cart_node: Node3D = cart as Node as Node3D
		if cart_node != null:
			controller.direction_look = -cart_node.global_basis.z
			controller.direction_look.y = 0.0
		controller.look_delta = Vector2.ZERO
	elif not rotating and focus < InteractionControlFocus.Priority.DRAWING:
		var carry_load: C_CarryLoad = entity.get_component(C_CarryLoad) as C_CarryLoad
		var strength: C_Strength = entity.get_component(C_Strength) as C_Strength
		_update_look(
			controller,
			entity as Node as Node3D,
			CarryLoadPolicy.active_multiplier(carry_load, strength),
		)

	if focus >= InteractionControlFocus.Priority.DRAWING:
		controller.move_axis = Vector2.ZERO
		controller.direction_motion = Vector3.ZERO
	else:
		_update_motion(controller)


func _update_look(
	controller: C_Controller,
	character: Node3D,
	mobility_multiplier: float,
) -> void:
	if character == null:
		return
	var look_direction: Vector3 = controller.direction_look
	if look_direction.is_zero_approx():
		look_direction = -character.global_basis.z
	look_direction = look_direction.normalized()
	var scaled_look_delta: Vector2 = controller.look_delta * clampf(
		mobility_multiplier,
		0.0,
		1.0,
	)
	look_direction = look_direction.rotated(
		Vector3.UP,
		-scaled_look_delta.x * LOOK_SENSITIVITY,
	)
	var current_pitch: float = asin(clampf(look_direction.y, -1.0, 1.0))
	var target_pitch: float = clampf(
		current_pitch - scaled_look_delta.y * LOOK_SENSITIVITY,
		-MAX_LOOK_PITCH,
		MAX_LOOK_PITCH,
	)
	var right_direction: Vector3 = look_direction.cross(Vector3.UP).normalized()
	controller.direction_look = look_direction.rotated(
		right_direction,
		target_pitch - current_pitch,
	).normalized()


func _update_motion(controller: C_Controller) -> void:
	var forward_direction: Vector3 = controller.direction_look
	forward_direction.y = 0.0
	if controller.move_axis.is_zero_approx() or forward_direction.is_zero_approx():
		controller.direction_motion = Vector3.ZERO
		return
	forward_direction = forward_direction.normalized()
	var right_direction: Vector3 = forward_direction.cross(Vector3.UP).normalized()
	controller.direction_motion = (
		right_direction * controller.move_axis.x - forward_direction * controller.move_axis.y
	)
