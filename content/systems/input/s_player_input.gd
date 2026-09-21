extends System
class_name S_PlayerInput


const LOOK_SENSITIVITY: float = 0.002
const MAX_LOOK_PITCH: float = deg_to_rad(89.0)
const DEAD_ZONE := 0.1

var look_mouse: Vector2 = Vector2.ZERO


func query() -> QueryBuilder:
	return q.with_all(
		[C_Controller, C_PlayerInputController]
	).iterate(
		[C_Controller]
	)


func process(
		entities: Array[Entity],
		components: Array,
		_delta: float
	) -> void:
	
	var controllers: Array = components[0]
	
	for idx in entities.size():
		var entity := entities[idx]
		var controller: C_Controller = controllers[idx]
		
		var character := entity as Node as Node3D
		
		_update_look(controller, character)
		_update_motion(controller)
		
		controller.action_main = Input.is_action_pressed(&"action_primary")
		controller.action_second = Input.is_action_pressed(&"action_secondary")
		controller.action_crouch = Input.is_action_pressed(&"crouch")
		controller.action_jump = Input.is_action_pressed(&"jump")
	
	look_mouse = Vector2.ZERO


func _update_look(
		controller: C_Controller,
		character: Node3D
	) -> void:
	
	var look_direction := controller.direction_look
	
	if look_direction.is_zero_approx():
		look_direction = -character.global_basis.z
	
	look_direction = look_direction.normalized()
	
	# Yaw.
	var yaw_delta := -look_mouse.x * LOOK_SENSITIVITY
	
	look_direction = look_direction.rotated(
		Vector3.UP,
		yaw_delta
	)
	
	# Pitch.
	var current_pitch := asin(
		clampf(
			look_direction.y,
			-1.0,
			1.0
		)
	)
	
	var pitch_delta := -look_mouse.y * LOOK_SENSITIVITY
	
	var target_pitch := clampf(
		current_pitch + pitch_delta,
		-MAX_LOOK_PITCH,
		MAX_LOOK_PITCH
	)
	
	var actual_pitch_delta := target_pitch - current_pitch
	
	var right := look_direction.cross(Vector3.UP).normalized()
	
	look_direction = look_direction.rotated(
		right,
		actual_pitch_delta
	)
	
	controller.direction_look = look_direction.normalized()


func _update_motion(controller: C_Controller) -> void:
	var input_vector := Input.get_vector(
		&"left",
		&"right",
		&"forward",
		&"back",
		DEAD_ZONE
	)
	
	input_vector += Input.get_vector(
		&"look_left",
		&"look_right",
		&"look_up",
		&"look_down",
		DEAD_ZONE
	)
	
	input_vector = input_vector.limit_length(1.0)
	
	if input_vector.is_zero_approx():
		controller.direction_motion = Vector3.ZERO
		return
	
	# Убираем pitch из направления взгляда.
	var forward := controller.direction_look
	forward.y = 0.0
	
	if forward.is_zero_approx():
		controller.direction_motion = Vector3.ZERO
		return
	
	forward = forward.normalized()
	
	var right := forward.cross(Vector3.UP).normalized()
	
	var motion := (
		right * input_vector.x
		- forward * input_vector.y
	)
	
	# Сохраняем аналоговую величину стика.
	controller.direction_motion = (
		motion.normalized()
		* input_vector.length()
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		look_mouse += event.relative
	
