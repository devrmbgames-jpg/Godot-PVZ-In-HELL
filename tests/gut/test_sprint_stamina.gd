extends GutTest
## Реальные компоненты/тело/намерение: минутный запас, вес, gates и восстановление.

class CapturedInput extends S_PlayerInput:
	func _accepts_input() -> bool:
		return true

var _world: World
var _body: RigidBody3D
var _actor: E_RigidBodyCharacter
var _motion: C_Motion
var _control: C_Controller
var _strength: C_Strength
var _stamina: C_Stamina
var _carry: C_CarryLoad
var _system: S_Sprint


func before_each() -> void:
	GameSettingsService.set_value("sprint_toggle", false)
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_body = RigidBody3D.new()
	_body.freeze = true
	_body.set_script(load("res://content/entities/characters/e_rigid_body_character.gd"))
	_actor = _body as Node as E_RigidBodyCharacter
	_motion = C_Motion.new()
	_motion.is_on_floor = true
	_control = C_Controller.new()
	_control.sprint_input_enabled = true
	_control.sprint_held = true
	_control.direction_motion = Vector3.FORWARD
	_strength = C_Strength.new()
	_strength.value = 1.0
	_stamina = C_Stamina.new()
	_carry = C_CarryLoad.new()
	_actor.component_resources = [_motion, _control, _strength, _stamina, _carry, C_GrabControl.new(), C_Crouch.new(), C_PlayerInputController.new()]
	add_child(_body)
	_world.add_entity(_actor, null, false)
	_motion = _actor.get_component(C_Motion) as C_Motion
	_motion.is_on_floor = true
	_control = _actor.get_component(C_Controller) as C_Controller
	_control.sprint_input_enabled = true
	_control.sprint_held = true
	_strength = _actor.get_component(C_Strength) as C_Strength
	_stamina = _actor.get_component(C_Stamina) as C_Stamina
	_carry = _actor.get_component(C_CarryLoad) as C_CarryLoad
	_body.linear_velocity = Vector3(0, 0, -6)
	_system = S_Sprint.new()


func after_each() -> void:
	GameSettingsService.set_value("sprint_toggle", false)
	Input.action_release(&"sprint")
	_system.free()
	_world.purge(false)
	_body.free()
	_world.free()
	ECS.world = null


func _tick(delta: float) -> void:
	_system.process([_actor], [[_stamina], [_control], [_motion], [_strength]], delta)


func test_one_hundred_lasts_sixty_seconds_and_strength_increases_capacity() -> void:
	for tick: int in 59:
		_tick(1.0)
	assert_almost_eq(_stamina.current, 100.0 / 60.0, 0.00001)
	assert_true(_stamina.running)
	assert_almost_eq(CharacterMotionSolver.effective_speed(_motion, _carry, _strength), 9.0, 0.00001)
	_tick(1.0)
	assert_eq(_stamina.current, 0.0)
	assert_true(_stamina.exhausted)
	assert_eq(_motion.sprint_multiplier, 1.0)
	_strength.value = 2.0
	_stamina.initialized = false
	_stamina.exhausted = false
	_tick(1.0)
	assert_eq(_stamina.maximum, 130.0)
	assert_almost_eq(_stamina.current, 130.0 - 100.0 / 60.0, 0.00001)


func test_carry_weight_scales_drain_and_respects_existing_slowdown() -> void:
	_carry.active = true
	_carry.mass_kg = 60.0
	_tick(1.0)
	assert_almost_eq(_stamina.drain_multiplier, 4.75, 0.00001)
	assert_almost_eq(_stamina.current, 100.0 - 100.0 / 60.0 * 4.75, 0.00001)
	assert_almost_eq(CharacterMotionSolver.effective_speed(_motion, _carry, _strength), 6.0, 0.00001)
	_carry.mass_kg = 120.0

	var reserve: float = _stamina.current
	_tick(1.0)
	assert_eq(_stamina.drain_multiplier, 8.0)
	assert_false(_stamina.running, "Неподвижный предельный груз не расходует запас")
	assert_eq(_stamina.current, reserve)
	_carry.mass_kg = 0.01
	_tick(1.0)
	assert_almost_eq(_stamina.drain_multiplier, 1.5, 0.001)


func test_idle_wall_air_crouch_modal_and_death_gate_running() -> void:
	_body.linear_velocity = Vector3.ZERO
	_tick(1.0)
	assert_eq(_stamina.current, 100.0, "Упор в стену не расходует выносливость")
	assert_eq(_motion.sprint_multiplier, 1.5, "Старт разрешён с нулевой скорости")
	_body.linear_velocity = Vector3.FORWARD * 6
	_control.direction_motion = Vector3.ZERO
	_tick(1.0)
	assert_false(_stamina.running)
	_control.direction_motion = Vector3.FORWARD
	_motion.is_on_floor = false
	_tick(1.0)
	assert_eq(_motion.sprint_multiplier, 1.0)
	_motion.is_on_floor = true
	_control.action_crouch = true
	_tick(1.0)
	assert_false(_stamina.running)
	_control.action_crouch = false

	var token: int = InteractionControlFocus.acquire(_actor, self, InteractionControlFocus.Priority.MODAL)
	_tick(1.0)
	assert_false(_stamina.running)
	InteractionControlFocus.release(_actor, token)
	_actor.add_component(C_Death.new())
	_tick(1.0)
	assert_false(_stamina.running)
	assert_eq(_motion.sprint_multiplier, 1.0)


func test_recovery_delay_and_exhaustion_hysteresis() -> void:
	_tick(60.0)
	assert_true(_stamina.exhausted)
	_control.sprint_held = false
	_tick(1.0)
	assert_eq(_stamina.current, 0.0)
	_tick(2.0)
	assert_eq(_stamina.current, 10.0, "Из 2 с одна прошла на cooldown")
	_control.sprint_held = true
	_tick(0.5)
	assert_eq(_motion.sprint_multiplier, 1.0)
	assert_eq(_stamina.current, 15.0)
	_tick(0.5)
	_tick(0.1)
	assert_true(_stamina.running)


func test_toggle_release_second_press_crouch_pause_and_mode_switch() -> void:
	GameSettingsService.set_value("sprint_toggle", true)
	_control.sprint_held = false
	_control.sprint_pressed = true
	_tick(0.1)
	_control.sprint_pressed = false
	_tick(0.1)
	assert_true(_stamina.running, "Toggle работает после отпускания")
	_control.sprint_pressed = true
	_tick(0.1)
	assert_false(_stamina.running, "Второе нажатие выключает")
	_tick(0.1)
	_control.sprint_pressed = false
	_system._notification(Node.NOTIFICATION_PAUSED)
	_tick(0.1)
	assert_false(_stamina.running, "Пауза сбрасывает toggle")
	_control.sprint_pressed = true
	_tick(0.1)
	_control.sprint_pressed = false
	_control.action_crouch = true
	_tick(0.1)
	_control.action_crouch = false
	_tick(0.1)
	assert_false(_stamina.running, "Приседание сбрасывает toggle")
	_control.sprint_pressed = true
	_tick(0.1)
	_control.sprint_pressed = false
	GameSettingsService.set_value("sprint_toggle", false)
	_tick(0.1)
	assert_false(_stamina.running, "Смена режима не оставляет скрытый toggle")


func test_input_producer_buffers_single_press_and_discards_pause() -> void:
	var input: CapturedInput = CapturedInput.new()
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.pressed = true
	input._unhandled_input(event)
	Input.action_press(&"sprint")
	input.process([_actor], [[_control]], 0.1)
	assert_true(_control.sprint_pressed)
	assert_true(_control.sprint_held)
	input.process([_actor], [[_control]], 0.1)
	assert_false(_control.sprint_pressed)
	assert_true(_control.sprint_held)
	input._unhandled_input(event)
	input._notification(Node.NOTIFICATION_PAUSED)
	Input.action_release(&"sprint")
	input.process([_actor], [[_control]], 0.1)
	assert_false(_control.sprint_pressed)
	assert_false(_control.sprint_held)
	input.free()


func test_project_defaults_are_shift_and_left_stick_click_with_atlas_prompts() -> void:
	var shift: InputEventKey = InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	var stick: InputEventJoypadButton = InputEventJoypadButton.new()
	stick.button_index = JOY_BUTTON_LEFT_STICK
	assert_true(InputMap.action_has_event(&"sprint", shift))
	assert_true(InputMap.action_has_event(&"sprint", stick))
	assert_true(GameSettingsService.ACTIONS.has(&"sprint"))
	assert_false(InputPromptService.textures(&"sprint", 0).is_empty())
	assert_false(InputPromptService.textures(&"sprint", 1).is_empty())


func test_snapshot_preserves_reserve_without_running_or_toggle_state() -> void:
	_stamina.current = 37.0
	_stamina.initialized = true
	_stamina.running = true
	_stamina.toggled = true
	var data: Dictionary = SaveDataCodec.component_data(_stamina)
	assert_true(data.fields.has("current"))
	assert_false(data.fields.has("toggled"))

	var restored: C_Stamina = C_Stamina.new()
	assert_true(SaveDataCodec.apply_fields(restored, data.fields as Dictionary))
	assert_eq(restored.current, 37.0)
	assert_true(restored.initialized)
	assert_false(restored.running)
	assert_false(restored.toggled)


func test_heavy_slow_motion_still_spends_reserve_near_weight_limit() -> void:
	_carry.active = true
	_carry.mass_kg = 119.0
	_body.linear_velocity = Vector3(0, 0, -0.05)
	_tick(1.0)
	assert_true(_stamina.running, "Медленное движение тяжёлого груза не даёт бесплатный бег")
	assert_gt(_stamina.drain_multiplier, 7.9)
	assert_lt(_stamina.current, 87.0)
