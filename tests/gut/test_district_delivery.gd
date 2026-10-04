extends "res://tests/gut/test_district_service.gd"
## Проверяет сохранность коробок, возвращение отложенных заказов и однократную оплату доставки.

var _player: Entity = null

#region Домашняя fixture
## Добавляет реальные журналы денег/регистрации и физические крепления посылок к районной fixture.
func before_each() -> void:
	super.before_each()
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.add_component(C_Wallet.new())
	session.add_component(C_PackageLedger.new())
	DayPhaseService.current().phase = C_DayCycle.Phase.EVENING
	var actor_node: RigidBody3D = RigidBody3D.new()
	actor_node.set_script(E_RigidBodyCharacter)
	_player = actor_node as Node as Entity

	var anchor: Marker3D = Marker3D.new()
	actor_node.add_child(anchor)
	(_player as E_RigidBodyCharacter).head_axis_x = anchor
	(_player as E_RigidBodyCharacter).hold_anchor = anchor
	_player.component_resources = [C_PlayerInputController.new(), C_GrabControl.new(), C_Health.new(), C_Controller.new(), C_CarryLoad.new(), C_Strength.new(), C_Motion.new()]
	_world.add_observer(O_GrabLifecycle.new())
	_world.add_entity(_player)
	actor_node.freeze = true

func _delivery_case(person: NpcRecord, suffix: String) -> CustomerVisit:
	var visit: CustomerVisit = _case(person, suffix)
	visit.payment = 10
	visit.definition = DEF_Customer.new()
	var parcel: E_Package = (load("res://content/entities/packages/package_a.tscn") as PackedScene).instantiate() as E_Package
	parcel.package_id = visit.package_id
	_world.add_entity(parcel)
	(parcel.get_component(C_Package) as C_Package).package_id = visit.package_id

	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	state.registration = C_PackageState.Registration.REGISTERED
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	var entry: PackageRegistrationRecord = PackageRegistrationRecord.new()
	entry.package_id = visit.package_id
	entry.number = ledger.records.size() + 1
	entry.active = true
	ledger.records.append(entry)
	return visit

func _door(address_id: StringName) -> Entity:
	for door: Entity in _world.query.with_all([C_NpcAddress]).execute():
		if (door.get_component(C_NpcAddress) as C_NpcAddress).address_id == address_id:
			return door
	return null
#endregion

#region Обязательства и деньги
## Отказ переносит тот же заказ на 1–3 дня, освобождая очередь без обещания и штрафа.
func test_declined_home_delivery_returns_once_after_one_to_three_days() -> void:
	DayPhaseService.current().phase = C_DayCycle.Phase.DAY
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "home_decline")
	visit.definition = load("res://content/definitions/gameplay/customers/def_customer_prototype.tres") as DEF_Customer
	visit.riddle_solved = true
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	NpcServiceRole.begin(body, person, visit, 1)
	var context: CustomerDialogueContext = CustomerDialogueContext.new(_player, body)
	assert_eq(context.dialogue_cue(), "home_request")
	assert_true(NpcHomeDeliveryService.decline(body))
	assert_between(visit.next_followup_day, 2, 4)
	var expected_day: int = visit.next_followup_day
	assert_true(visit.finished)
	assert_true(visit.home_delivery_declined)
	assert_false(body.has_component(C_CustomerAgent))
	assert_eq(_district.home_deliveries.size(), 0)
	assert_null(visit.complaint)
	assert_eq(CustomerFlowService.reactivate_due_followups(CustomerFlowService.current(), expected_day - 1), 0)
	assert_eq(CustomerFlowService.reactivate_due_followups(CustomerFlowService.current(), expected_day), 1)
	assert_false(visit.finished)
	assert_eq(visit.arrival_day, expected_day)
	assert_false(NpcHomeDeliveryService.decline(body))
	assert_null(NpcHomeDeliveryService.offer_for(body))
	var copy: CustomerVisit = CustomerVisit.new()
	var fields: Dictionary = (SaveDataCodec.encode(visit) as Dictionary).fields as Dictionary
	assert_true(SaveDataCodec.apply_fields(copy, fields))
	assert_true(copy.home_delivery_declined)
	assert_eq(copy.arrival_day, expected_day)

## Лимит принятых доставок относится ко всему дню; панели и прошедшее время его не обновляют.
func test_two_optional_jobs_and_night_failure_keep_physical_boxes() -> void:
	var first: CustomerVisit = _delivery_case(_district.people[0], "home_first")
	var second: CustomerVisit = _delivery_case(_district.people[3], "home_second")
	_delivery_case(_district.people[6], "home_third")
	var parcel: Entity = CustomerFlowService.parcel_for(first.package_id)
	var pose: Transform3D = (parcel as Node as Node3D).global_transform
	assert_true(NpcHomeDeliveryService.accept(DistrictPopulationService.body_for(first.customer_id)))
	assert_true(NpcHomeDeliveryService.accept(DistrictPopulationService.body_for(second.customer_id)))
	assert_false(NpcHomeDeliveryService.accept(DistrictPopulationService.body_for(_district.people[6].npc_id)))
	assert_eq(_district.home_deliveries.size(), 2)
	NpcHomeDeliveryService.finish_evening(1)
	NpcHomeDeliveryService.finish_evening(1)
	assert_same(CustomerFlowService.parcel_for(first.package_id), parcel)
	assert_eq((parcel as Node as Node3D).global_transform, pose)
	assert_eq(first.declaration, CustomerVisit.Declaration.NONE)
	assert_eq(first.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(first.arrival_day, 2)
	assert_eq(_district.people[0].memories.size(), 1)
	assert_eq(WalletService.current().balance, 0)

## Выдача у двери использует настоящую удерживаемую коробку и ровно две денежные операции.
func test_home_handoff_and_bonus_are_once() -> void:
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "home_receive")
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.HOME)
	assert_true(NpcHomeDeliveryService.accept(body))
	var job: NpcHomeDelivery = _district.home_deliveries[0]
	assert_true(NpcHomeDeliveryService.knock(_player, _door(person.home_id)))

	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _player))
	assert_eq(CustomerFlowService.confirm_direct_delivery(_player, body), PackageDeliveryCheck.Result.READY)
	assert_eq(visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_null(CustomerFlowService.parcel_for(visit.package_id))
	assert_true(NpcHomeDeliveryService.complete(job))

	var balance: int = WalletService.current().balance
	assert_eq(WalletService.current().operations.size(), 2)
	assert_eq(balance, visit.payment * visit.satisfaction / CustomerOutcomeService.SATISFACTION_SCALE + visit.payment)
	assert_true(NpcHomeDeliveryService.complete(job))
	NpcHomeDeliveryService.finish_evening(1)
	assert_eq(WalletService.current().balance, balance)
	assert_eq(WalletService.current().operations.size(), 2)

## Отказ сохраняет физическую коробку и не начисляет доплату доставки.
func test_refusal_has_no_bonus() -> void:
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "home_refuse")
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	assert_true(NpcHomeDeliveryService.accept(body))
	visit.actual = CustomerVisit.Actual.CUSTOMER_REFUSED
	assert_true(NpcHomeDeliveryService.complete(_district.home_deliveries[0]))
	assert_not_null(CustomerFlowService.parcel_for(visit.package_id))
	assert_false(_district.home_deliveries[0].bonus_committed)
	assert_eq(WalletService.current().balance, 0)

## Домашний осмотр резервирует дверь и физическую коробку; прерывание освобождает обе связи.
func test_home_inspection_stays_at_door_and_releases_cargo() -> void:
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "home_inspect")
	visit.definition.private_inspection = true
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var door: Entity = _door(person.home_id)
	assert_true(NpcHomeDeliveryService.accept(body))
	assert_true(NpcHomeDeliveryService.knock(_player, door))

	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	assert_true(CustomerInspectionService.begin(body, visit, parcel))
	assert_eq(agent.phase, C_CustomerAgent.Phase.INSPECTING)
	assert_same(CustomerInspectionService.owner_for(parcel), body)
	assert_eq(body.get_relationships(Relationship.new(R_InspectingAt.new(), door)).size(), 1)
	NpcServiceRole.suspend(body)
	assert_null(CustomerInspectionService.owner_for(parcel))
	assert_null(PhysicalSlotService.relationship(parcel))
	assert_null(NpcHomeDeliveryService.meeting_for(body))
	assert_same(CustomerFlowService.parcel_for(visit.package_id), parcel)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
#endregion
