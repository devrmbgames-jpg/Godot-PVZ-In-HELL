extends System
class_name S_PlayerInput

const LOOK_SENSITIVITY: float = 0.002
const MAX_LOOK_PITCH: float = deg_to_rad(89.0)
const DEAD_ZONE: float = 0.1
const GAMEPAD_LOOK_PIXELS_PER_SECOND: float = 900.0

var look_mouse: Vector2 = Vector2.ZERO
var _interact_pending: bool = false
var _throw_pending: bool = false
var _use_pending: bool = false
var _secondary_pending: bool = false


#region Godot input
func _unhandled_input(event: InputEvent) -> void:
	if not _accepts_input():
		return
	if event is InputEventMouseMotion:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		look_mouse += mouse_event.relative
	if event.is_action_pressed(&"interact") and not event.is_echo():
		_interact_pending = true
	if event.is_action_pressed(&"action_primary") and not event.is_echo():
		_throw_pending = true
	if event.is_action_pressed(&"use") and not event.is_echo():
		_use_pending = true
	if event.is_action_pressed(&"action_secondary") and not event.is_echo():
		_secondary_pending = true
#endregion


#region GECS
func query() -> QueryBuilder:
	return q.with_all([C_Controller, C_PlayerInputController]).iterate([C_Controller])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var controllers: Array = components[0]
	var captured: bool = _accepts_input()
	var gamepad_look: Vector2 = Input.get_vector(
		&"look_left",
		&"look_right",
		&"look_up",
		&"look_down",
		DEAD_ZONE,
	)
	for entity_index: int in entities.size():
		var entity: Entity = entities[entity_index]
		var controller: C_Controller = controllers[entity_index]
		controller.input_tick += 1
		controller.use_pressed = captured and _use_pending
		controller.action_second_pressed = captured and _secondary_pending
		controller.physical_override = captured and Input.is_action_pressed(&"physical_override")
		controller.interact_pressed = captured and _interact_pending
		controller.action_main_pressed = captured and _throw_pending
		controller.action_main = captured and Input.is_action_pressed(&"action_primary")
		controller.action_second = captured and Input.is_action_pressed(&"action_secondary")
		controller.action_second_held = controller.action_second
		controller.action_crouch = captured and Input.is_action_pressed(&"crouch")
		controller.action_jump = captured and Input.is_action_pressed(&"jump")
		controller.look_delta = (
			look_mouse + gamepad_look * GAMEPAD_LOOK_PIXELS_PER_SECOND * delta
			if captured
			else Vector2.ZERO
		)
		var rotating: bool = InteractionActions.wants_rotation(entity, controller)
		if not rotating:
			_update_look(controller, entity as Node as Node3D)
		_update_motion(controller, captured)
	look_mouse = Vector2.ZERO
	_interact_pending = false
	_throw_pending = false
	_use_pending = false
	_secondary_pending = false
#endregion


#region Intent helpers
func _accepts_input() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _update_look(controller: C_Controller, character: Node3D) -> void:
	var look_direction: Vector3 = controller.direction_look
	if look_direction.is_zero_approx():
		look_direction = -character.global_basis.z
	look_direction = look_direction.normalized()
	look_direction = look_direction.rotated(Vector3.UP, -controller.look_delta.x * LOOK_SENSITIVITY)
	var current_pitch: float = asin(clampf(look_direction.y, -1.0, 1.0))
	var target_pitch: float = clampf(
		current_pitch - controller.look_delta.y * LOOK_SENSITIVITY,
		-MAX_LOOK_PITCH,
		MAX_LOOK_PITCH,
	)
	var right_direction: Vector3 = look_direction.cross(Vector3.UP).normalized()
	var rotated_direction: Vector3 = look_direction.rotated(
		right_direction,
		target_pitch - current_pitch,
	)
	controller.direction_look = rotated_direction.normalized()


func _update_motion(controller: C_Controller, captured: bool) -> void:
	var input_vector: Vector2 = (
		Input.get_vector(&"left", &"right", &"forward", &"back", DEAD_ZONE)
		if captured
		else Vector2.ZERO
	)
	var forward_direction: Vector3 = controller.direction_look
	forward_direction.y = 0.0
	if input_vector.is_zero_approx() or forward_direction.is_zero_approx():
		controller.direction_motion = Vector3.ZERO
		return
	forward_direction = forward_direction.normalized()
	var right_direction: Vector3 = forward_direction.cross(Vector3.UP).normalized()
	controller.direction_motion = (
		right_direction * input_vector.x - forward_direction * input_vector.y
	)
#endregion
