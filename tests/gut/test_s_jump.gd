extends GutTest

var jump_system: S_Jump
var actor: Entity
var jump_state: C_Jump
var controller_state: C_Controller
var motion_state: C_Motion


func before_each() -> void:
	jump_system = S_Jump.new()
	actor = Entity.new()
	jump_state = C_Jump.new()
	controller_state = C_Controller.new()
	motion_state = C_Motion.new()
	motion_state.is_on_floor = true
	autofree(jump_system)
	autofree(actor)


func test_grounded_press_adds_jump_without_overwriting_external_impulse() -> void:
	motion_state.pending_impulse = Vector3(3.0, 2.0, -1.0)
	jump_state.jump_force = 10.0
	controller_state.action_jump = true
	_tick_jump()
	assert_eq(motion_state.pending_impulse, Vector3(3.0, 12.0, -1.0))
	assert_true(jump_state.active)
	assert_false(motion_state.is_on_floor)


func test_held_button_does_not_repeat_on_landing() -> void:
	controller_state.action_jump = true
	_tick_jump()
	motion_state.pending_impulse = Vector3.ZERO
	motion_state.is_on_floor = true
	_tick_jump()
	assert_eq(motion_state.pending_impulse, Vector3.ZERO)
	assert_false(jump_state.active)


func test_release_and_press_allows_another_grounded_jump() -> void:
	controller_state.action_jump = true
	_tick_jump()
	motion_state.pending_impulse = Vector3.ZERO
	controller_state.action_jump = false
	_tick_jump()
	motion_state.is_on_floor = true
	controller_state.action_jump = true
	_tick_jump()
	assert_eq(motion_state.pending_impulse, Vector3.UP * jump_state.jump_force)
	assert_true(jump_state.active)


func test_airborne_press_is_not_buffered_until_landing() -> void:
	motion_state.is_on_floor = false
	controller_state.action_jump = true
	_tick_jump()
	assert_eq(motion_state.pending_impulse, Vector3.ZERO)
	assert_false(jump_state.active)
	motion_state.is_on_floor = true
	_tick_jump()
	assert_eq(motion_state.pending_impulse, Vector3.ZERO)


func test_disabled_control_rejects_press_without_delaying_it() -> void:
	motion_state.control_enabled = false
	controller_state.action_jump = true
	_tick_jump()
	assert_false(jump_state.active)
	assert_eq(motion_state.pending_impulse, Vector3.ZERO)
	motion_state.control_enabled = true
	_tick_jump()
	assert_eq(motion_state.pending_impulse, Vector3.ZERO)


func test_nonpositive_force_does_not_start_jump() -> void:
	jump_state.jump_force = -1.0
	controller_state.action_jump = true
	_tick_jump()
	assert_false(jump_state.active)
	assert_true(motion_state.is_on_floor)
	assert_eq(motion_state.pending_impulse, Vector3.ZERO)


func _tick_jump() -> void:
	var actors: Array[Entity] = [actor]
	jump_system.process(actors, [[jump_state], [controller_state], [motion_state]], 0.016)
