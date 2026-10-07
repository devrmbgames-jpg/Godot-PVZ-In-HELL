extends "res://tests/gut/test_morning_truck.gd"
## Утренняя разгрузка, повторная проверка запроса, ручной LOST и безопасный lifecycle двери.

var _cycle: C_DayCycle
var _flow: C_CustomerFlow
var _phase_system: S_DayPhase
var _session: Entity
var _player_body: RigidBody3D

#region Сессия фаз и физический игрок
## Дополняет реальную машину журналом визитов и простым зарегистрированным телом игрока.
func before_each() -> void:
	super.before_each()
	_session = _world.query.with_all([C_DayCycle]).execute_one()
	_cycle = _session.get_component(C_DayCycle) as C_DayCycle
	_session.add_component(C_CustomerFlow.new())
	_session.add_component(C_Wallet.new())
	_flow = _session.get_component(C_CustomerFlow) as C_CustomerFlow
	_flow.schedule = load("res://content/definitions/gameplay/customers/def_customer_schedule_default.tres") as DEF_CustomerSchedule
	_phase_system = S_DayPhase.new()
	_world.add_system(_phase_system)

	_player_body = RigidBody3D.new()
	_player_body.set_script(load("res://addons/gecs/ecs/entity.gd"))
	_player_body.freeze = true
	_player_body.position = Vector3(0, 0, -5)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 1.7
	collision.shape = shape
	collision.position.y = 0.85
	_player_body.add_child(collision)
	var player: Entity = _player_body as Node as Entity
	player.component_resources = [C_PlayerInputController.new()]
	_world.add_entity(player)


func _complete_and_unload() -> E_MorningTruck:
	var truck: E_MorningTruck = await _ready_truck()
	_plan_big_boxes()
	for index: int in _state.incoming_package_ids.size():
		ReceivingDeliveryService.deliver_one(_zone, _state, 1)
		assert_eq(_parcels().size(), index + 1)
		var body: RigidBody3D = _parcels()[index] as Node as RigidBody3D
		body.freeze = true
		body.global_position = _parking.global_position + Vector3(5 + index * 2, 0, 0)
		await get_tree().physics_frame
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	assert_true(_state.pending.is_empty())
	return truck


func _request() -> DayTransitionRequest:
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.START_SHIFT
	request.expected_day = _cycle.day_index
	request.expected_phase = _cycle.phase
	return request


func _execute_transition() -> void:
	_phase_system.process([_session], [[_cycle]], 0.0)
	_phase_system.cmd.execute()


func _put_back(truck: E_MorningTruck) -> void:
	var body: RigidBody3D = _parcels()[0] as Node as RigidBody3D
	body.global_transform = truck.cargo_slots[0].global_transform


func _visit_for(package_id: String) -> CustomerVisit:
	for visit: CustomerVisit in _flow.visits:
		if visit.package_id == package_id:
			return visit
	return null


func _enter_truck(truck: E_MorningTruck) -> void:
	_player_body.global_position = truck.global_transform * Vector3(0, 0.2, 0.7)
#endregion


#region Реальное условие начала смены
## Неподготовленное утро не допускает смену прежде первой работы поставки.
func test_unprepared_supply_blocks_start_without_mutating_batch() -> void:
	assert_false(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.START_SHIFT))
	assert_true(DayPhaseService.shift_status(_cycle).contains("ещё не подготовлена"))
	assert_eq(_state.last_started_day, 0)


## Неполная поставка и находящийся в кузове груз имеют отдельные точные причины и количества.
func test_partial_supply_and_loaded_box_share_ui_and_execution_blockers() -> void:
	await _ready_truck()
	_plan_big_boxes()
	ReceivingDeliveryService.deliver_one(_zone, _state, 1)
	var status: ReceivingShiftService.Status = ReceivingShiftService.status(_cycle)
	assert_eq(status.pending, 1)
	assert_eq(status.inside, 1)
	assert_eq(status.missing, 0)
	assert_false(DayPhaseService.submit(_request()))
	for reason: String in status.reasons:
		assert_true(DayPhaseService.shift_status(_cycle).contains(reason))
	var debug_result: DebugServiceResult = DebugWorldService.day_next()
	assert_false(debug_result.success)
	assert_eq(debug_result.details, status.reasons)
	_zone._process(1.0)
	var sign: Label3D = _zone.get_node("Sign") as Label3D
	assert_true(sign.text.contains("Выгрузите коробки из машины: 1"))


## Вынос снимает запрет; физическое возвращение коробки снова требует выгрузки без задержки Area.
func test_unloading_and_putting_back_recompute_current_physical_bounds() -> void:
	var truck: E_MorningTruck = await _complete_and_unload()
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.START_SHIFT))
	_put_back(truck)
	assert_false(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.START_SHIFT))
	assert_eq(ReceivingShiftService.status(_cycle).inside, 1)
	(_parcels()[0] as Node as Node3D).global_position.x += 5
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.START_SHIFT))


## Центр снаружи ещё не означает полного выноса; повёрнутый кузов использует собственные оси.
func test_partial_exit_and_rotated_cargo_use_full_body_bounds() -> void:
	_parking.rotation.y = PI / 3.0
	var truck: E_MorningTruck = await _complete_and_unload()
	var body: RigidBody3D = _parcels()[0] as Node as RigidBody3D
	body.global_transform = truck.cargo_area.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.9, 0.3, 0.3))
	assert_eq(ReceivingShiftService.status(_cycle).inside, 1)
	assert_false(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.START_SHIFT))
	body.global_position = truck.cargo_area.global_transform * Vector3(1.6, 0.3, 0.3)
	assert_eq(ReceivingShiftService.status(_cycle).inside, 0)
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.START_SHIFT))


## Игрок в кузове блокирует начало; выход допускается по актуальной позе тела в том же кадре.
func test_player_must_leave_cargo_before_start() -> void:
	var truck: E_MorningTruck = await _complete_and_unload()
	_enter_truck(truck)
	assert_true(DayPhaseService.start_blockers(_cycle).has("Выйдите из кузова"))
	assert_false(DayPhaseService.submit(_request()))
	assert_false(truck.is_departing())
	_player_body.global_position.x += 5
	assert_true(DayPhaseService.submit(_request()))
	_execute_transition()
	assert_eq(_cycle.phase, C_DayCycle.Phase.DAY)


## Отсутствующая коробка требует настоящего заявления LOST даже до регистрации.
func test_absent_unregistered_package_requires_manual_lost_and_keeps_receipt() -> void:
	await _complete_and_unload()
	var identity: C_Package = _parcels()[0].get_component(C_Package) as C_Package
	var package_id: String = identity.package_id
	var visit: CustomerVisit = _visit_for(package_id)
	assert_not_null(visit)
	var receipt: PackageRegistrationRecord = PackageHistoryService.record_for(package_id)
	_world.remove_entity(_parcels()[0])
	assert_eq(ReceivingShiftService.status(_cycle).missing, 1)
	assert_false(DayPhaseService.submit(_request()))
	assert_false(CustomerFlowService.package_declared_lost(package_id))
	assert_same(PackageHistoryService.record_for(package_id), receipt)
	assert_eq(receipt.number, 0)

	assert_true(CustomerFlowService.declare(visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_eq(ReceivingShiftService.status(_cycle).missing, 0)
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.START_SHIFT))


## Терминально повреждённый, ещё живой узел не считается обычной разгруженной коробкой.
func test_destroyed_package_never_automatically_declares_lost() -> void:
	await _complete_and_unload()
	var parcel: Entity = _parcels()[0]
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var condition: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	condition.damage = C_PackageState.Damage.DESTROYED
	assert_eq(ReceivingShiftService.status(_cycle).missing, 1)
	assert_false(CustomerFlowService.package_declared_lost(identity.package_id))
	var visit: CustomerVisit = _visit_for(identity.package_id)
	assert_true(CustomerFlowService.declare(visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.START_SHIFT))


## Неправильная авторская область не скрывает груз и не разрешает смену.
func test_invalid_cargo_volume_fails_closed() -> void:
	var truck: E_MorningTruck = await _complete_and_unload()
	(truck.cargo_area.get_node("CollisionShape3D") as CollisionShape3D).disabled = true
	assert_false(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.START_SHIFT))
	assert_true(DayPhaseService.shift_status(_cycle).contains("Машина ещё не готова"))
#endregion


#region Отложенная фиксация и отправление
## Возвращённая после запроса коробка отменяет команду до начала смены.
func test_start_request_revalidates_after_box_returns() -> void:
	var truck: E_MorningTruck = await _complete_and_unload()
	assert_true(DayPhaseService.submit(_request()))
	_put_back(truck)
	_execute_transition()
	assert_eq(_cycle.phase, C_DayCycle.Phase.MORNING)
	assert_null(_cycle.pending_transition)
	assert_false(truck.is_departing())


## Игрок, вошедший после планирования до flush CommandBuffer, отменяет окончательную фиксацию.
func test_command_buffer_revalidates_player_before_commit() -> void:
	var truck: E_MorningTruck = await _complete_and_unload()
	assert_true(DayPhaseService.submit(_request()))
	_phase_system.process([_session], [[_cycle]], 0.0)
	_enter_truck(truck)
	_phase_system.cmd.execute()
	assert_eq(_cycle.phase, C_DayCycle.Phase.MORNING)
	assert_false(truck.is_departing())


## Обратный груз обрабатывается один раз вне итерации и до перехода в DAY; ID фиксации сохраняется.
func test_cargo_hook_precedes_phase_change_and_is_idempotent() -> void:
	var truck: E_MorningTruck = await _complete_and_unload()
	var observations: Dictionary[String, int] = {"calls": 0, "phase": -1}
	var extra: Entity = Entity.new()
	_world.add_entity(extra)
	_zone.cargo_commit_requested.connect(func(_truck_instance: E_MorningTruck, _batch_id: String) -> void:
		observations["calls"] += 1
		observations["phase"] = _cycle.phase
		_world.remove_entity(extra)
	)
	assert_true(DayPhaseService.submit(_request()))
	_execute_transition()
	truck.set_physics_process(false)
	assert_eq(observations["calls"], 1)
	assert_eq(observations["phase"], C_DayCycle.Phase.MORNING)
	assert_eq(_cycle.phase, C_DayCycle.Phase.DAY)
	assert_false(DayPhaseService.submit(_request()))
	assert_eq(_state.dispatched_batch_id, _state.batch_id)

	var copied: C_Receiving = C_Receiving.new()
	assert_true(SaveDataCodec.apply_fields(copied, SaveDataCodec.component_data(_state).fields as Dictionary))
	assert_eq(copied.dispatched_batch_id, _state.batch_id)
	assert_false(ReceivingShiftService.commit_departure(_cycle))
	assert_eq(observations["calls"], 1)


## Вошедший во время закрытия игрок удерживает открытую дверь; после выхода lifecycle завершается.
func test_player_entering_during_close_reopens_door_without_blocking_day() -> void:
	var truck: E_MorningTruck = await _complete_and_unload()
	assert_true(DayPhaseService.submit(_request()))
	_execute_transition()
	truck.set_physics_process(false)
	truck._physics_process(0.1)
	assert_eq(truck.door_animation.current_animation, "door_close")
	_enter_truck(truck)
	truck._physics_process(0.1)
	assert_lt((truck.get_node("Door") as Node3D).scale.y, 0.2)
	assert_true((truck.get_node("CollisionShapeDoor") as CollisionShape3D).disabled)
	truck._physics_process(truck.departure_timeout_seconds + 1.0)
	assert_false(truck.is_queued_for_deletion())
	assert_eq(_cycle.phase, C_DayCycle.Phase.DAY)

	_player_body.global_position.x += 5
	truck._physics_process(0.1)
	truck.door_animation.advance(1.0)
	truck._physics_process(0.1)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(truck))
	assert_eq(_parcels().size(), 2)


## Остановленное время анимации не удерживает отправление дольше авторского предела.
func test_animation_failure_has_bounded_departure() -> void:
	var truck: E_MorningTruck = await _complete_and_unload()
	assert_true(DayPhaseService.submit(_request()))
	_execute_transition()
	truck.set_physics_process(false)
	truck.door_animation.speed_scale = 0.0
	truck._physics_process(0.1)
	assert_false(truck.is_queued_for_deletion())
	truck._physics_process(truck.departure_timeout_seconds)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(truck))
	assert_eq(_cycle.phase, C_DayCycle.Phase.DAY)
	assert_eq(_parcels().size(), 2)
#endregion
