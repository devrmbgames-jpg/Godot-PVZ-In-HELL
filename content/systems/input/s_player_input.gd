extends System
## Captures raw device input into C_Controller without deciding gameplay control mode.
class_name S_PlayerInput

const GAMEPAD_LOOK_PIXELS_PER_SECOND: float = 900.0

var _look_mouse: Vector2 = Vector2.ZERO
var _interact_pending: bool = false
var _throw_pending: bool = false
var _use_pending: bool = false
var _secondary_pending: bool = false
var _drop_start_pending: bool = false
var _drop_end_pending: bool = false
var _cancel_pending: bool = false
var _sprint_pending: bool = false


func _notification(what: int) -> void:
	if what != NOTIFICATION_PAUSED:
		return

	_clear_pending()
	if not is_instance_valid(ECS.world):
		return

	for actor: Entity in ECS.world.query.with_all([C_Controller, C_PlayerInputController]).execute():
		var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
		_update_drop(controller, actor, false, 0.0)
		controller.sprint_pressed = false
		controller.sprint_held = false
		controller.sprint_input_enabled = false


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"menu") or event.is_echo():
		return
	if not is_instance_valid(ECS.world):
		return

	var players: QueryBuilder = ECS.world.query.with_all([C_PlayerInputController, C_GrabControl])
	for actor: Entity in players.execute():
		if InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.DRAWING:
			_cancel_pending = true
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not _accepts_input():
		return
	if event is InputEventMouseMotion:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		_look_mouse += mouse_event.screen_relative
	if event.is_action_pressed(&"sprint") and not event.is_echo():
		_sprint_pending = true
	if event.is_action_pressed(&"interact") and not event.is_echo():
		_interact_pending = true
	if event.is_action_pressed(&"action_primary") and not event.is_echo():
		_throw_pending = true
	if event.is_action_pressed(&"use") and not event.is_echo():
		_use_pending = true
	if event.is_action_pressed(&"action_secondary") and not event.is_echo():
		_secondary_pending = true
	if event.is_action_pressed(&"drop") and not event.is_echo():
		_drop_start_pending = true
	if event.is_action_released(&"drop"):
		_drop_end_pending = true


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
		float(GameSettingsService.value("deadzone")),
	)

	var move_axis: Vector2 = (
		Input.get_vector(&"left", &"right", &"forward", &"back", float(GameSettingsService.value("deadzone")))
		if captured else Vector2.ZERO
	)
	for entity_index: int in entities.size():
		var entity: Entity = entities[entity_index]
		var controller: C_Controller = controllers[entity_index]
		controller.input_tick += 1
		controller.sprint_input_enabled = captured
		controller.sprint_pressed = captured and _sprint_pending
		controller.sprint_held = captured and Input.is_action_pressed(&"sprint")
		controller.cancel_pressed = _cancel_pending
		controller.rotate_held = captured and Input.is_action_pressed(&"rotate_held")
		_update_drop(controller, entity, captured, delta)
		controller.use_pressed = captured and _use_pending
		controller.use_held = captured and Input.is_action_pressed(&"use")
		controller.interact_held = captured and Input.is_action_pressed(&"interact")
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
			_look_mouse * float(GameSettingsService.value("mouse_sensitivity")) + gamepad_look * GAMEPAD_LOOK_PIXELS_PER_SECOND * delta * float(GameSettingsService.value("gamepad_sensitivity"))
			if captured else Vector2.ZERO
		)
		controller.move_axis = move_axis

	_clear_pending()


## Пауза не переносит старое движение мыши/нажатия в следующий игровой tick.
func _clear_pending() -> void:
	_look_mouse = Vector2.ZERO
	_interact_pending = false
	_throw_pending = false
	_use_pending = false
	_secondary_pending = false
	_drop_start_pending = false
	_drop_end_pending = false
	_cancel_pending = false
	_sprint_pending = false


func _update_drop(controller: C_Controller, entity: Entity, captured: bool, delta: float) -> void:
	controller.drop_pressed = false
	controller.drop_long_pressed = false
	if not captured:
		controller.drop_tracking = false
		controller.drop_elapsed = 0.0
		controller.drop_long_fired = false
		return
	if _drop_start_pending:
		controller.drop_tracking = true
		controller.drop_elapsed = 0.0
		controller.drop_long_fired = false
	if not controller.drop_tracking:
		return

	controller.drop_elapsed += delta
	var control: C_GrabControl = entity.get_component(C_GrabControl) as C_GrabControl
	if (
		control != null and controller.drop_elapsed >= control.drop_long_press_seconds
		and not controller.drop_long_fired
	):
		controller.drop_long_fired = true
		controller.drop_long_pressed = true
	if _drop_end_pending:
		controller.drop_pressed = not controller.drop_long_fired
		controller.drop_tracking = false


func _accepts_input() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
