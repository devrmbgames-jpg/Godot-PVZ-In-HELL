extends GutTest

var _world: World = null
var _actor: Entity = null
var _switch: Entity = null
var _state: C_LightCircuit = null


func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_LightCircuit.new())
	_world.add_observer(O_LightFlicker.new())
	_actor = Entity.new()
	_world.add_entity(_actor)
	var scene: PackedScene = load("res://content/entities/props/light_switch.tscn") as PackedScene
	_switch = scene.instantiate() as Entity
	_world.add_entity(_switch)
	_state = _switch.get_component(C_LightCircuit) as C_LightCircuit


func after_each() -> void:
	_world.free()
	ECS.world = null
	_world = null
	_actor = null
	_switch = null
	_state = null


func _light(group_id: StringName) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	_world.add_child(light)
	light.add_to_group(group_id)
	return light


func test_toggle_updates_circuit_and_only_its_authored_light_groups() -> void:
	var light: OmniLight3D = _light(&"warehouse_lights")
	var unrelated: OmniLight3D = _light(&"outside_lights")
	assert_true(LightCircuitService.toggle(_switch))
	assert_false(light.visible)
	assert_true(unrelated.visible)
	assert_false(LightCircuitService.is_enabled(&"warehouse"))
	assert_true(LightCircuitService.toggle(_switch))
	assert_true(light.visible)
	assert_true(LightCircuitService.is_enabled(&"warehouse"))


func test_restored_disabled_state_and_late_lights_are_synchronized() -> void:
	_state.enabled = false
	_world.process(1.0 / 60.0)
	var light: OmniLight3D = _light(&"warehouse_lights")
	_world.process(1.0 / 60.0)
	assert_false(light.visible)
	assert_false(_state.enabled)


func test_multiple_groups_and_non_light_members_are_safe() -> void:
	_state.light_groups.append(&"counter_lights")
	var first: OmniLight3D = _light(&"warehouse_lights")
	var second: OmniLight3D = _light(&"counter_lights")
	var unrelated: Node = Node.new()
	_world.add_child(unrelated)
	unrelated.add_to_group(&"warehouse_lights")
	assert_true(LightCircuitService.set_enabled(_switch, false))
	assert_false(first.visible)
	assert_false(second.visible)


func test_disabled_or_removed_switch_cannot_be_activated() -> void:
	var action: DEF_LightSwitchAction = DEF_LightSwitchAction.new()
	assert_true(action.is_available(_actor, _switch, _switch))
	(_switch.get_component(C_Interactable) as C_Interactable).enabled = false
	assert_false(action.is_available(_actor, _switch, _switch))
	action.execute(_actor, _switch, _switch)
	assert_true(_state.enabled)
	_world.remove_entity(_switch)
	assert_false(LightCircuitService.set_enabled(_switch, false))
	assert_false(action.is_available(_actor, null, null))
	assert_false(LightCircuitService.toggle(null))


func test_flicker_subscriber_changes_visual_only_and_switch_off_wins() -> void:
	var light: OmniLight3D = _light(&"warehouse_lights")
	var view: CircuitLightView = CircuitLightView.new()
	view.name = "CircuitLightView"
	light.add_child(view)
	view.set_process(false)
	assert_true(LightCircuitService.flicker(&"warehouse", 2.0, 0.1))
	view._process(0.15)
	assert_false(light.visible)
	assert_true(_state.enabled, "A dark flicker pulse is not a switched-off room")
	_world.process(0.1)
	assert_false(light.visible, "Circuit synchronization must not overwrite the flicker")
	view._process(0.1)
	assert_true(light.visible)
	assert_true(LightCircuitService.set_enabled(_switch, false))
	assert_false(light.visible)
	view._process(0.1)
	assert_false(light.visible)
	assert_true(LightCircuitService.set_enabled(_switch, true))
	view._process(0.1)
	assert_true(light.visible, "Switching on must not resume the stale request")


func test_flicker_expires_and_does_not_affect_other_circuits() -> void:
	var light: OmniLight3D = _light(&"warehouse_lights")
	var view: CircuitLightView = CircuitLightView.new()
	view.name = "CircuitLightView"
	light.add_child(view)
	view.set_process(false)
	var unrelated: OmniLight3D = _light(&"outside_lights")
	var other: CircuitLightView = CircuitLightView.new()
	other.circuit_id = &"outside"
	unrelated.add_child(other)
	other.set_process(false)
	assert_false(LightCircuitService.flicker(&"missing", 2.0, 0.1))
	assert_false(LightCircuitService.flicker(&"warehouse", -1.0, 0.1))
	assert_true(LightCircuitService.flicker(&"warehouse", 0.3, 0.1))
	view._process(0.15)
	other._process(0.15)
	assert_false(light.visible)
	assert_true(unrelated.visible)
	view._process(0.2)
	assert_true(light.visible)
	assert_true(_state.enabled)
