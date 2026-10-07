extends GutTest
## Проверяет появление клиента, объявление номера и первый диалог с физической проверкой видимости.

## Бюджет ожидания асинхронной строки диалога, в кадрах.
const UI_FRAMES: int = 32
var _world: World
var _actor: E_RigidBodyCharacter
var _flow: C_CustomerFlow
var _cycle: C_DayCycle
var _ledger: C_PackageLedger
var _visit: CustomerVisit
var _customer: E_Customer


#region Тестовое окружение и ожидание UI
## Создаёт авторский визит, физического игрока и стойку с отдельным журналом.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_GrabLifecycle.new())
	var owner: Entity = Entity.new()
	_flow = C_CustomerFlow.new()
	_flow.schedule = DEF_CustomerSchedule.new()
	_flow.schedule.customer_scene = load("res://content/entities/customers/customer.tscn") as PackedScene
	_flow.planned_through_day = 1
	_cycle = C_DayCycle.new()
	_cycle.phase = C_DayCycle.Phase.DAY
	_ledger = C_PackageLedger.new()
	owner.component_resources = [_flow, _cycle, _ledger, C_Wallet.new()]
	_world.add_entity(owner)
	_flow = owner.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle = owner.get_component(C_DayCycle) as C_DayCycle
	_ledger = owner.get_component(C_PackageLedger) as C_PackageLedger

	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.set_script(E_RigidBodyCharacter)
	_actor = body as Node as E_RigidBodyCharacter
	var anchor: Marker3D = Marker3D.new()
	anchor.position.y = 1.3
	body.add_child(anchor)
	_actor.hold_anchor = anchor
	_actor.head_axis_x = anchor
	_actor.component_resources = [C_PlayerInputController.new(), C_Controller.new(), C_GrabControl.new(), C_CarryLoad.new(), C_Strength.new()]
	_world.add_entity(_actor)

	var counter: E_DeliveryCounter = (load("res://content/entities/stations/delivery_counter.tscn") as PackedScene).instantiate() as E_DeliveryCounter
	(counter as Node as Node3D).position.x = 10.0
	_world.add_entity(counter)
	_visit = CustomerVisit.new()
	_visit.visit_id = &"visit/introduction"
	_visit.package_id = "intro/parcel"
	_visit.definition = DEF_Customer.new()
	_flow.visits = [_visit]


## Закрывает активные модальные диалоги перед удалением World.
func after_each() -> void:
	for node: Node in get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP):
		(node as CustomerDialoguePanel).close_dialogue()
	await get_tree().process_frame
	await get_tree().process_frame
	_world.purge(false)
	_world.free()
	ECS.world = null


func _register_order() -> void:
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = _visit.package_id
	record.number = 73
	record.active = true
	_ledger.records = [record]


func _spawn() -> void:
	assert_true(CustomerFlowFixture.spawn(_flow, _cycle))
	_customer = CustomerFlowService.customer_for(_visit.visit_id)
	assert_not_null(_customer)
	(_customer as Node as RigidBody3D).freeze = true


func _agent() -> C_CustomerAgent:
	return _customer.get_component(C_CustomerAgent) as C_CustomerAgent


func _panel() -> CustomerDialoguePanel:
	var panels: Array[Node] = get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP)
	return panels[0] as CustomerDialoguePanel if not panels.is_empty() else null


func _await_line() -> void:
	for frame: int in UI_FRAMES:
		await get_tree().process_frame
		var panel: CustomerDialoguePanel = _panel()
		if panel != null and panel._line != null:
			return

	assert_true(false, "Dialogue line must finish within the bounded fixture")


#endregion

#region Объявление заказа
## Быстрое обслуживание однократно объявляет реальный номер и принимает коробку без диалога.
func test_quick_spawn_announces_true_number_preserves_it_and_accepts_without_dialogue() -> void:
	_visit.definition.introduction = DEF_Customer.Introduction.ANNOUNCE_ORDER
	_register_order()
	_spawn()
	var message: Label3D = _customer.get_node("Message") as Label3D
	assert_true(message.text.contains("073"))
	assert_true(_agent().order_announced)
	assert_null(_panel())

	var text: String = message.text
	(_customer.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	CustomerFlowFixture.advance(_flow, _cycle, 0.0)
	CustomerFlowService.greet(_customer)
	assert_eq(message.text, text)
	assert_false(CustomerDialogueService.start(_actor, _customer))
	assert_false((DEF_CustomerAction.new()).is_available(_actor, _customer, _customer))
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_GrabbableBody)

	var parcel: Entity = body as Node as Entity
	var identity: C_Package = C_Package.new()
	identity.package_id = _visit.package_id
	var state: C_PackageState = C_PackageState.new()
	state.registration = C_PackageState.Registration.REGISTERED
	state.registration_number = 73
	parcel.component_resources = [identity, state, C_Grabbable.new()]
	_world.add_entity(parcel)
	CustomerFlowService.bind_parcel(_customer, _visit)
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	assert_eq(CustomerFlowService.confirm_direct_delivery(_actor, _customer), PackageDeliveryCheck.Result.READY)
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_eq(_agent().phase, C_CustomerAgent.Phase.RECEIVING)
	assert_false(_agent().dialogue_started)


## Поздняя регистрация объявляет номер один раз; загадка и настенный номер сохраняют отдельные режимы.
func test_quick_pending_registration_announces_once_and_riddle_wall_profiles_keep_contract() -> void:
	_visit.requires_registered_package = false
	_visit.definition.introduction = DEF_Customer.Introduction.ANNOUNCE_ORDER
	_spawn()
	assert_false(_agent().order_announced)
	_register_order()
	CustomerFlowFixture.advance(_flow, _cycle, 0.0)
	assert_true(_agent().order_announced)

	var message: Label3D = _customer.get_node("Message") as Label3D
	message.text = "Другой результат"
	CustomerFlowFixture.advance(_flow, _cycle, 0.0)
	assert_eq(message.text, "Другой результат", "Repeated ticks do not republish the bubble")
	_visit.definition.dialogue_mode = DEF_Customer.DialogueMode.RIDDLE
	assert_false(CustomerPresentation.uses_quick_order(_visit.definition))
	var gaze: DEF_Customer = (load("res://content/definitions/gameplay/customers/def_customer_gaze.tres") as DEF_Customer).duplicate() as DEF_Customer
	gaze.introduction = DEF_Customer.Introduction.ANNOUNCE_ORDER
	assert_true(CustomerPresentation.uses_wall_order(gaze))
	assert_false(CustomerPresentation.uses_quick_order(gaze))


#endregion

#region Первый разговор и приоритет ввода
## Первый диалог требует близости, видимости и свободного ввода; закрытие не запускает его повторно.
func test_first_approach_checks_range_wall_and_busy_capture_then_starts_only_once() -> void:
	_visit.definition.introduction = DEF_Customer.Introduction.FIRST_APPROACH_DIALOGUE
	_register_order()
	_spawn()
	_agent().phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	(_customer as Node as Node3D).position = Vector3(0, 0, -4)
	CustomerFlowFixture.greet(_customer)
	assert_null(_panel())
	(_customer as Node as Node3D).position = Vector3(0, 0, -1.5)

	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = Vector3(0, 1.5, -0.75)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(3, 3, 0.2)
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	CustomerFlowFixture.greet(_customer)
	assert_null(_panel(), "Walls block involuntary conversation")
	wall.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	Console.toggle_console()
	CustomerFlowFixture.greet(_customer)
	assert_null(_panel(), "The developer console keeps input focus")
	Console.toggle_console()

	var capture: int = InteractionControlFocus.acquire(_actor, self, InteractionControlFocus.Priority.MODAL)
	CustomerFlowFixture.greet(_customer)
	assert_false(_agent().dialogue_started)
	assert_null(_panel())
	InteractionControlFocus.release(_actor, capture)
	CustomerFlowFixture.greet(_customer)
	assert_true(_agent().dialogue_started)
	assert_eq(_agent().phase, C_CustomerAgent.Phase.DIALOGUE)
	assert_not_null(_panel())
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.MODAL)
	await _await_line()
	_panel().close_dialogue()
	await get_tree().process_frame
	CustomerFlowFixture.greet(_customer)
	assert_null(_panel())
	assert_eq(_agent().phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)


## Ручной разговор расходует защиту первого контакта; уходящий и погибший клиент не начинают разговор.
func test_manual_start_consumes_auto_guard_and_leaving_or_dead_customer_never_starts() -> void:
	_register_order()
	_spawn()
	_agent().phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	(_customer as Node as Node3D).position = Vector3(0, 0, -1.5)
	CustomerFlowFixture.greet(_customer)
	assert_null(_panel(), "Manual profile still waits for interaction")
	assert_true(CustomerDialogueService.start(_actor, _customer))
	await _await_line()
	_panel().close_dialogue()
	await get_tree().process_frame
	_visit.definition.introduction = DEF_Customer.Introduction.FIRST_APPROACH_DIALOGUE
	CustomerFlowFixture.greet(_customer)
	assert_null(_panel(), "The first successful conversation already consumed the guard")
	_agent().dialogue_started = false
	_agent().phase = C_CustomerAgent.Phase.LEAVING
	CustomerFlowFixture.greet(_customer)
	assert_null(_panel())

#endregion
	_agent().phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_customer.add_component(C_Death.new())
	CustomerFlowFixture.greet(_customer)
	assert_null(_panel())
