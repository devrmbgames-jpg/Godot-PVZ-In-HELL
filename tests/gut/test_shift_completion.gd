extends GutTest
## Проверяет запрос и фиксацию конца смены, включая физическое присутствие клиентов в комнате.

var _world: World
var _owner: Entity
var _cycle: C_DayCycle
var _flow: C_CustomerFlow
var _system: S_DayPhase


#region Тестовое окружение
## Создаёт дневной World и систему фаз для прямой проверки команды завершения смены.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_owner = Entity.new()
	_owner.component_resources = [C_DayCycle.new(), C_CustomerFlow.new()]
	_world.add_entity(_owner)
	_cycle = _owner.get_component(C_DayCycle) as C_DayCycle
	_flow = _owner.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle.phase = C_DayCycle.Phase.DAY
	_system = S_DayPhase.new()
	_world.add_child(_system)


## Освобождает систему вместе с World и сбрасывает ECS.world.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _request(kind: DayTransitionRequest.Kind) -> DayTransitionRequest:
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = kind
	request.expected_day = _cycle.day_index
	request.expected_phase = _cycle.phase
	return request


func _visit(day: int, registered: bool = true) -> CustomerVisit:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.arrival_day = day
	visit.requires_registered_package = not registered
	_flow.visits.append(visit)
	return visit


#endregion

#region Условия и фиксация перехода
## Поступление без номера не блокирует смену; после сканирования возможный приход учитывается отдельно.
func test_independent_gates_combine_and_unregistered_planned_arrivals_are_explicit() -> void:
	var pending: CustomerVisit = _visit(1, false)
	pending.package_id = "pending"
	_owner.add_component(C_PackageLedger.new())
	var receipt: PackageRegistrationRecord = PackageRegistrationRecord.new()
	receipt.package_id = pending.package_id
	receipt.received_day = 1
	PackageRegistrationService.ledger().records.append(receipt)
	var future: CustomerVisit = _visit(2)
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT), "Legacy actionable filter does not trap unregistered visits")
	_cycle.require_all_planned_arrivals = true
	_cycle.minimum_shift_seconds = 240.0
	assert_eq(DayPhaseService.finish_blockers(_cycle).size(), 1)
	assert_false(DayPhaseService.submit(_request(DayTransitionRequest.Kind.FINISH_SHIFT)))
	_cycle.shift_elapsed_seconds = 240.0
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT), "Receipt without registration cannot enable an unreachable arrival")
	receipt.number = 1
	assert_false(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT))
	pending.started = true
	assert_false(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT), "Arrived still requires service when legacy gate enabled")
	_cycle.require_finished_customers = false
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT), "Future visit does not block today's planned arrivals")
	assert_false(future.started)
	pending.started = false
	pending.finished = true
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT), "Explicitly closed/cancelled visit cannot trap the day")
	assert_true(CustomerDebugPresentation.summary().contains("Завершение доступно"))


## Решение опирается на действующие визиты, а не устаревший производный счётчик.
func test_live_actionable_visits_override_stale_derived_event_count() -> void:
	var pending: CustomerVisit = _visit(1)
	_cycle.remaining_customer_events = 0
	assert_false(DayPhaseService.submit(_request(DayTransitionRequest.Kind.FINISH_SHIFT)))
	assert_true(DebugWorldService.day_next().details[0].contains("Завершить визиты"))
	pending.finished = true
	_cycle.remaining_customer_events = 99
	assert_true(DayPhaseService.submit(_request(DayTransitionRequest.Kind.FINISH_SHIFT)))
	_system.process([_owner], [[_cycle]], 0.0)
	assert_eq(_cycle.phase, C_DayCycle.Phase.EVENING)


## Отложенная команда повторно проверяет условия; часы идут только во время дневной смены.
func test_queued_finish_revalidates_and_clock_advances_only_during_shift() -> void:
	_cycle.minimum_shift_seconds = 60.0
	_cycle.shift_elapsed_seconds = 60.0
	assert_true(DayPhaseService.submit(_request(DayTransitionRequest.Kind.FINISH_SHIFT)))
	var late: CustomerVisit = _visit(1)
	_system.process([_owner], [[_cycle]], 5.0)
	assert_eq(_cycle.phase, C_DayCycle.Phase.DAY, "Arrival after submission blocks commit")
	assert_eq(_cycle.shift_elapsed_seconds, 65.0)
	assert_null(_cycle.pending_transition)
	late.finished = true
	assert_true(DayPhaseService.submit(_request(DayTransitionRequest.Kind.FINISH_SHIFT)))
	_system.process([_owner], [[_cycle]], 0.0)
	_system.process([_owner], [[_cycle]], 30.0)
	assert_eq(_cycle.shift_elapsed_seconds, 65.0)
	_cycle.phase = C_DayCycle.Phase.MORNING
	assert_true(DayPhaseService.submit(_request(DayTransitionRequest.Kind.START_SHIFT)))
	_system.process([_owner], [[_cycle]], 2.0)
	assert_eq(_cycle.phase, C_DayCycle.Phase.DAY)
	assert_eq(_cycle.shift_elapsed_seconds, 0.0)
	_system.process([_owner], [[_cycle]], NAN)
	assert_eq(_cycle.shift_elapsed_seconds, 0.0)


#endregion

#region Физическое присутствие в комнате
## Настроенная Area учитывает живые тела внутри; отсутствующая зона блокирует завершение.
func test_configured_room_counts_live_customer_bodies_only() -> void:
	_cycle.require_finished_customers = false
	_cycle.require_empty_customer_room = true
	_cycle.customer_room_path = NodePath("Room")
	assert_false(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT), "Missing configured room fails closed")
	var room: Area3D = Area3D.new()
	room.name = "Room"
	room.collision_mask = 2

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(4, 4, 4)
	collision.shape = shape
	room.add_child(collision)
	_owner.add_child(room)
	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.position = Vector3(8, 0, 0)
	body.collision_layer = 2
	body.set_script(load("res://content/entities/customers/e_customer.gd"))

	var customer: E_Customer = body as Node as E_Customer
	customer.component_resources = [C_CustomerAgent.new()]
	var body_shape: CollisionShape3D = CollisionShape3D.new()
	body_shape.shape = SphereShape3D.new()
	body.add_child(body_shape)
	_world.add_entity(customer)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(DayPhaseService.customers_in_room(_cycle), 0)
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT), "Outside customer doesn't block configured building")
	_cycle.customer_room_path = NodePath("")
	assert_false(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT), "No room means conservative all-live fallback")
	_cycle.customer_room_path = NodePath("Room")
	body.global_position = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(DayPhaseService.customers_in_room(_cycle), 1)
	assert_false(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT))
	customer.add_component(C_Death.new())
	assert_true(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT), "Dead remains are not live visitors")

#endregion
