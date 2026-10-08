extends Node
## Старый сквозной сценарий main_level: стойка, терминал, жалобы и утренние остатки поставки.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 300
var _level: Node = null
var _counter: E_DeliveryCounter = null
var _cycle: C_DayCycle = null


#region Исторический сценарий обслуживания
func _ready() -> void:
	_run.call_deferred()


## Проверяет прежний ассортимент из восьми коробок; требует согласования с текущей районной поставкой.
func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = scene.instantiate()
	add_child(_level)
	_level.set_physics_process(false)
	_counter = CustomerFlowQueries.counter()
	_cycle = DayPhaseQueries.current()
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = flow.schedule.duplicate(true) as DEF_CustomerSchedule
	for event: DEF_CustomerEvent in flow.schedule.events:
		event.customer.greeting_seconds = 0.05
		event.customer.receiving_seconds = 0.05
		event.customer.leaving_seconds = 0.05
	for frame: int in WAIT_FRAMES:
		GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break

	assert(ECS.world.query.with_all([C_Package]).execute().size() == 8)
	var actor: Entity = _level.get_node("Entityes/Player") as Entity
	(actor as Node as RigidBody3D).freeze = true
	for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
		(parcel as Node as RigidBody3D).freeze = true
	var books: Entity = PackageQueries.find_live_package("base_supply:1:books")
	var glass: Entity = PackageQueries.find_live_package("base_supply:1:glass")
	var clothes: Entity = PackageQueries.find_live_package("base_supply:1:clothes")
	var late: Entity = PackageQueries.find_live_package("base_supply:1:equipment")
	_register(books)
	_register(late)

	var late_number: int = (late.get_component(C_PackageState) as C_PackageState).registration_number
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
	assert(_cycle.remaining_customer_events == 1)
	_transition(DayTransitionRequest.Kind.START_SHIFT)
	assert(not DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT))
	var customer: E_NpcCharacter = await _wait_for_customer()
	var first: CustomerVisit = CustomerFlowQueries.find_visit((customer.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id)
	assert(first.package_id == "base_supply:1:books")
	assert(CustomerFlowService.confirm_delivery(_counter) == PackageDeliveryCheck.Result.MISSING)
	_register(glass)

	var glass_origin: Vector3 = (glass as Node as Node3D).global_position
	await _place(glass)
	assert(CustomerFlowService.confirm_delivery(_counter) == PackageDeliveryCheck.Result.WRONG_PACKAGE)
	(glass as Node as Node3D).global_position = glass_origin
	await _place(books)
	var number: int = (books.get_component(C_PackageState) as C_PackageState).registration_number
	var action: DEF_DeliveryAction = DEF_DeliveryAction.new()
	assert(action.is_available(actor, _counter, _counter))
	action.execute(actor, _counter, _counter)
	assert(first.actual == CustomerVisit.Actual.DELIVERED)
	assert(first.declaration == CustomerVisit.Declaration.NONE)
	assert(PackageRegistrationService.smallest_free_number(PackageQueries.ledger()) == number)

	var terminal: E_Terminal = _level.get_node("Entityes/Terminal") as E_Terminal
	terminal.open_for(actor)
	var first_line: UI_TerminalButtonPackage = _terminal_line_for(terminal, first.package_id)
	assert(first_line != null)
	var taken: Button = first_line.get_node("%ButtonOK") as Button
	taken.pressed.emit()
	taken.pressed.emit()
	assert(first.declaration == CustomerVisit.Declaration.TAKEN)
	assert(WalletService.current().balance == first.payment)
	terminal.close_panel()
	customer = await _wait_for_customer()

	var second: CustomerVisit = CustomerFlowQueries.find_visit((customer.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id)
	assert(second.package_id == "base_supply:1:glass")
	second.complaint_roll = 0.0
	var glass_state: C_PackageState = glass.get_component(C_PackageState) as C_PackageState
	glass_state.damage = C_PackageState.Damage.DAMAGED
	glass_state.opening = C_PackageState.Opening.OPENED
	await _place(glass)
	assert(CustomerFlowService.confirm_delivery(_counter) == PackageDeliveryCheck.Result.READY)
	assert(second.actual == CustomerVisit.Actual.CUSTOMER_REFUSED)
	assert(is_instance_valid(glass))
	assert(CustomerFlowService.declare(second.visit_id, CustomerVisit.Declaration.REFUSED))
	_register(clothes)
	customer = await _wait_for_customer()

	var third: CustomerVisit = CustomerFlowQueries.find_visit((customer.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id)
	third.complaint_roll = 0.0
	third.aggression_roll = 0.0
	assert(CustomerFlowService.declare(third.visit_id, CustomerVisit.Declaration.TAKEN))
	assert(third.actual == CustomerVisit.Actual.NOT_RESOLVED)
	assert((customer.get_component(C_CustomerAgent) as C_CustomerAgent).phase == C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	var dialogue_context: CustomerDialogueContext = CustomerDialogueContext.new(actor, customer)
	assert(dialogue_context.dialogue_cue() == "false_taken")
	assert(dialogue_context.begin())
	assert(dialogue_context.schedule_non_delivery_complaint())
	assert(dialogue_context.enter_aggressive())
	assert((customer.get_component(C_CustomerAgent) as C_CustomerAgent).phase == C_CustomerAgent.Phase.AGGRESSIVE)
	GameTimeFixture.gameplay(ECS.world, third.definition.aggressive_seconds)
	GameTimeFixture.gameplay(ECS.world, third.definition.leaving_seconds)
	# Результат испытания ухода применяется до следующего удаления клиента из обслуживания.
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
	assert(_cycle.remaining_customer_events == 0)
	assert(DayPhaseService.permits(_cycle, DayTransitionRequest.Kind.FINISH_SHIFT))
	_transition(DayTransitionRequest.Kind.FINISH_SHIFT)
	assert(WalletService.current().completed_days == 1)
	_transition(DayTransitionRequest.Kind.SLEEP)
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
	assert(_cycle.day_index == 2 and _cycle.phase == C_DayCycle.Phase.MORNING)
	assert(third.complaint.outcome == CustomerComplaint.Outcome.CONFIRMED)
	assert(second.complaint.outcome == CustomerComplaint.Outcome.CONFIRMED)

	var glass_record: PackageRegistrationRecord = _registration_for_package(second.package_id)
	assert(glass_record != null and glass_record.active)
	assert(second.disposition == CustomerVisit.Disposition.WAREHOUSE)
	assert(is_instance_valid(glass))
	assert(is_instance_valid(late))
	assert((late.get_component(C_PackageState) as C_PackageState).registration_number == late_number)
	assert(CustomerFlowQueries.find_visit(&"visit/base_supply:1:equipment").arrival_day == 11)
	assert(PackageQueries.find_live_package("base_supply:1:bottles") != null)
	_level.free()
	ECS.world = null
	print("R11 customer physical delivery and dispute smoke PASS")
	get_tree().quit()


#endregion

#region Управление тестовой фазой и физическими участниками
func _transition(kind: DayTransitionRequest.Kind) -> void:
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = kind
	request.expected_day = _cycle.day_index
	request.expected_phase = _cycle.phase
	assert(DayPhaseService.submit(request))
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)


func _wait_for_customer() -> E_NpcCharacter:
	for frame: int in WAIT_FRAMES:
		GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
		await get_tree().physics_frame
		var customer: E_NpcCharacter = CustomerFlowQueries.waiting_customer()
		if customer != null:
			return customer

	for entity: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var agent: C_CustomerAgent = entity.get_component(C_CustomerAgent) as C_CustomerAgent
		var body: RigidBody3D = entity as Node as RigidBody3D
		var intent: C_NpcIntent = entity.get_component(C_NpcIntent) as C_NpcIntent
		print("Customer timeout: phase=", agent.phase, " elapsed=", agent.elapsed, " moving=", intent.movement_active, " position=", body.global_position, " destination=", intent.move_position, " velocity=", body.linear_velocity)
	assert(false, "Customer must physically reach the authored counter within frame budget")
	return null


func _place(parcel: Entity) -> void:
	# Тест размещает коробку; игровое подтверждение само не перемещает её со склада.
	(parcel as Node as Node3D).global_position = (_counter as Node as Node3D).global_position + Vector3.UP * 1.3
	for frame: int in 12:
		await get_tree().physics_frame
		if _counter.parcels().size() == 1 and _counter.parcels()[0] == parcel:
			return

	assert(false, "Physical overlap must match the placed parcel")


func _register(parcel: Entity) -> void:
	# Создаётся запись регистрации; физическое взаимодействие со сканером проверяет отдельный сценарий.
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var ledger: C_PackageLedger = PackageQueries.ledger()
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = identity.package_id
	record.history_id = identity.history_id
	record.definition = identity.definition
	record.number = PackageRegistrationService.smallest_free_number(ledger)
	record.day_index = _cycle.day_index
	ledger.records.append(record)
	state.registration = C_PackageState.Registration.REGISTERED
	state.scan = C_PackageState.Scan.SCANNED
	state.registration_number = record.number
	state.registration_day = _cycle.day_index


#endregion

#region Поиск записей учёта
func _terminal_line_for(terminal: E_Terminal, package_id: String) -> UI_TerminalButtonPackage:
	var package_list: VBoxContainer = terminal.get_node("TerminalPanel/%PackageList") as VBoxContainer
	for child: Node in package_list.get_children():
		var line: UI_TerminalButtonPackage = child as UI_TerminalButtonPackage
		if line != null and line.package_id() == package_id:
			return line
	return null


func _registration_for_package(package_id: String) -> PackageRegistrationRecord:
	var ledger: C_PackageLedger = PackageQueries.ledger()
	if ledger == null:
		return null

	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == package_id:
			return record
	return null

#endregion
