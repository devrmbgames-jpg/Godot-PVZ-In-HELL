extends "res://tests/gut/test_district_service.gd"
## Home promises conserve boxes, return unfinished cases and settle payments once.

var _player: Entity = null

#region Home fixture
## Adds the actual economic and registration journals and physical parcel holders.
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

#region Obligations and money
## Acceptance quota applies to the entire day, independent of open panels or elapsed time.
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

## Actual receipt uses the ordinary held-box path at the door and pays exactly two operations.
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

## Refusal preserves the actual parcel and awards no delivery bonus.
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

## A real home inspection reserves its own door and physical cargo, then interruption releases both.
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
