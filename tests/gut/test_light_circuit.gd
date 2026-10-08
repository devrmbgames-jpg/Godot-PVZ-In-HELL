extends GutTest
## Проверяет авторские группы ламп, синхронизацию цепи и временное мерцание.

var _world: World = null
var _actor: Entity = null
var _switch: Entity = null
var _state: C_LightCircuit = null


#region Тестовое окружение
## Создаёт цепь из prefab выключателя и систему синхронизации/observer мерцания.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_LightCircuit.new())
	_world.add_observer(O_LightFlicker.new())
	_world.add_observer(O_LightCircuitPresentation.new())
	_actor = Entity.new()
	_world.add_entity(_actor)

	var scene: PackedScene = load("res://content/entities/props/light_switch.tscn") as PackedScene
	_switch = scene.instantiate() as Entity
	_world.add_entity(_switch)
	_state = _switch.get_component(C_LightCircuit) as C_LightCircuit


## Удаляет World и очищает сохранённые ссылки на цепь и участников.
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


#endregion

#region Авторская цепь
## A replaced loaded circuit invalidates a queued projection while preserving its current state.
func test_queued_projection_revalidates_circuit_component_identity() -> void:
	var queued: O_LightCircuitPresentation = O_LightCircuitPresentation.new()
	queued.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	for observer: Observer in _world.observers:
		if observer is O_LightCircuitPresentation:
			_world.remove_observer(observer)
	_world.add_observer(queued)
	var light: OmniLight3D = _light(&"warehouse_lights")
	assert_true(LightCircuitService.set_enabled(_switch, false))
	assert_false(_state.enabled)
	assert_true(light.visible, "Presentation is deferred; the command state is already committed")
	var replacement: C_LightCircuit = C_LightCircuit.new()
	_switch.add_component(replacement)
	_world.flush_command_buffers()
	assert_true(light.visible)
	assert_true(replacement.enabled)
	assert_false(_state.enabled)


## Переключение меняет состояние цепи и только её авторские группы ламп.
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


## Восстановленная отключённая цепь синхронизирует и поздно добавленные лампы.
func test_restored_disabled_state_and_late_lights_are_synchronized() -> void:
	_state.enabled = false
	_world.process(1.0 / 60.0)
	var light: OmniLight3D = _light(&"warehouse_lights")
	_world.process(1.0 / 60.0)
	assert_false(light.visible)
	assert_false(_state.enabled)


## Несколько групп отключаются совместно, а участники без Light3D безопасно пропускаются.
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


## Отключённый или удалённый выключатель недоступен для действия.
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


#endregion

#region Временное мерцание
## Лампа, готовая раньше глобального World, получает первый запрос после завершения ready сцены.
func test_view_ready_before_world_receives_first_flicker() -> void:
	ECS.world = null
	var light: OmniLight3D = _light(&"warehouse_lights")
	var view: CircuitLightView = CircuitLightView.new()
	view.name = "CircuitLightView"
	light.add_child(view)
	view.set_process(false)
	ECS.world = _world
	await get_tree().process_frame
	assert_true(LightCircuitService.flicker(&"warehouse", 2.0, 0.1))
	view._process(0.15)
	assert_false(light.visible, "First request must arrive even before the view's first process tick")
	assert_true(_state.enabled)


## Мерцание не меняет enabled цепи; явное выключение отменяет текущую просьбу мерцания.
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


## Мерцание истекает по времени и не затрагивает чужую цепь.
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

#endregion
