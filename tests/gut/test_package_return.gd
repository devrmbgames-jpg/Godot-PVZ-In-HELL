extends GutTest

var _world: World = null
var _cycle: C_DayCycle = null
var _visit: CustomerVisit = null
var _parcel: Entity = null
var _record: PackageRegistrationRecord = null
var _actor: Entity = null


func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_PackageLedger.new(), C_CustomerFlow.new(), C_Wallet.new()]
	_world.add_entity(session)
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.MORNING
	_cycle.day_index = 2
	_record = PackageRegistrationRecord.new()
	_record.package_id = "refused:1"
	_record.number = 7
	_record.day_index = 1
	(session.get_component(C_PackageLedger) as C_PackageLedger).records.append(_record)
	_visit = CustomerVisit.new()
	_visit.package_id = _record.package_id
	_visit.arrival_day = 1
	_visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	_visit.declaration = CustomerVisit.Declaration.REFUSED
	_visit.settlement_committed = true
	_visit.money_delta = -150
	(session.get_component(C_CustomerFlow) as C_CustomerFlow).visits.append(_visit)
	_parcel = Entity.new()

	var identity: C_Package = C_Package.new()
	identity.package_id = _record.package_id
	var state: C_PackageState = C_PackageState.new()
	state.registration = C_PackageState.Registration.REGISTERED
	state.registration_number = _record.number
	_parcel.component_resources = [identity, state]
	_world.add_entity(_parcel)
	_actor = Entity.new()
	_actor.component_resources = [C_GrabControl.new()]
	_world.add_entity(_actor)


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func test_both_actual_refusal_kinds_are_returnable_next_morning_only() -> void:
	for actual: CustomerVisit.Actual in [CustomerVisit.Actual.PLAYER_DENIED, CustomerVisit.Actual.CUSTOMER_REFUSED]:
		_visit.actual = actual
		assert_true(PackageReturnService.can_return(_parcel))
		_cycle.day_index = 1
		assert_false(PackageReturnService.can_return(_parcel))
		_cycle.day_index = 2
	_cycle.phase = C_DayCycle.Phase.EVENING
	assert_false(PackageReturnService.can_return(_parcel))
	assert_true(_record.active)


func test_terminal_refused_cannot_invent_actual_refusal_or_return_future_target() -> void:
	_visit.actual = CustomerVisit.Actual.NOT_RESOLVED
	assert_false(PackageReturnService.can_return(_parcel))
	_visit.actual = CustomerVisit.Actual.DELIVERED
	assert_false(PackageReturnService.can_return(_parcel))
	_visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	_visit.arrival_day = 11
	assert_false(PackageReturnService.can_return(_parcel))
	assert_true(_record.active)


func test_registration_identity_and_active_number_are_required() -> void:
	_record.active = false
	assert_false(PackageReturnService.can_return(_parcel))
	_record.active = true
	_record.number = 8
	assert_false(PackageReturnService.can_return(_parcel))
	_record.number = 7
	_visit.package_id = "different:parcel"
	assert_false(PackageReturnService.can_return(_parcel))
	_visit.package_id = _record.package_id
	(_parcel.get_component(C_PackageState) as C_PackageState).registration = C_PackageState.Registration.RETURNED
	assert_false(PackageReturnService.can_return(_parcel))


func test_unheld_parcel_does_not_exit_release_number_or_change_settlement() -> void:
	assert_true(PackageReturnService.can_return(_parcel))
	assert_false(PackageReturnService.return_held(_actor))
	assert_true(_record.active)
	assert_eq((_parcel.get_component(C_PackageState) as C_PackageState).registration, C_PackageState.Registration.REGISTERED)
	assert_eq(_visit.disposition, CustomerVisit.Disposition.WAREHOUSE)
	assert_eq(_visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.REFUSED)
	assert_true(_visit.settlement_committed)
	assert_eq(_visit.money_delta, -150)
	assert_true(_world.entities.has(_parcel))
