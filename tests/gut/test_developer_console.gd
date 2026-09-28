extends GutTest

const MAIN_LEVEL: PackedScene = preload("res://content/scenes/main_level.tscn")

var _world: World = null
var _level: Node3D = null
var _cycle: C_DayCycle = null
var _wallet: C_Wallet = null
var _flow: C_CustomerFlow = null
var _ledger: C_PackageLedger = null


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	elif is_instance_valid(_world):
		_world.free()
	_level = null
	_world = null
	_cycle = null
	_wallet = null
	_flow = null
	_ledger = null
	ECS.world = null


func _create_core_world() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	_cycle = C_DayCycle.new()
	_wallet = C_Wallet.new()
	_flow = C_CustomerFlow.new()
	_ledger = C_PackageLedger.new()
	session.component_resources = [_cycle, _wallet, _flow, _ledger]
	_world.add_entity(session)
	# Entity resources are runtime-owned after insertion; reacquire authoritative instances.
	_cycle = DayPhaseService.current()
	_wallet = WalletService.current()
	_flow = CustomerFlowService.current()
	_ledger = PackageRegistrationService.ledger()


func _add_player() -> Entity:
	var player: Entity = Entity.new()
	player.component_resources = [C_PlayerInputController.new(), C_Interactor.new()]
	_world.add_entity(player)
	return player


func _add_package(package_id: String) -> Entity:
	var definition: DEF_Package = DEF_Package.new()
	definition.key = &"test"
	definition.accounting_value = 100
	var identity: C_Package = C_Package.new()
	identity.package_id = package_id
	identity.definition = definition
	var parcel: Entity = Entity.new()
	parcel.component_resources = [identity, C_PackageState.new()]
	_world.add_entity(parcel)
	return parcel


func _add_visit(package_id: String, suffix: String = "") -> CustomerVisit:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = StringName("visit/%s%s" % [package_id, suffix])
	visit.package_id = package_id
	visit.customer_id = StringName("debug_customer%s" % suffix)
	visit.definition = DEF_Customer.new()
	visit.accounting_value = 100
	visit.payment = 100
	visit.started = true
	visit.finished = true
	_flow.visits.append(visit)
	return visit


func _debug_packages() -> Array[Entity]:
	var result: Array[Entity] = []
	for entity: Entity in ECS.world.query.with_all([C_Package]).execute():
		var identity: C_Package = entity.get_component(C_Package) as C_Package
		if identity != null and identity.package_id.begins_with(DebugPackageService.DEBUG_ID_PREFIX):
			result.append(entity)
	return result


func _process_gameplay(ticks: int = 1) -> void:
	for tick: int in ticks:
		ECS.world.process(1.0 / 60.0, "GamePlay")


func test_target_resolver_uses_stable_identity_and_rejects_freed_handles() -> void:
	_create_core_world()
	var player: Entity = _add_player()
	var parcel: Entity = _add_package("debug:test:1")
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	interactor.target = parcel

	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = identity.package_id
	record.day_index = 1
	record.number = 1
	record.definition = identity.definition
	_ledger.records.append(record)
	var visit: CustomerVisit = _add_visit(identity.package_id)

	var self_target: DebugTarget = DebugTargetResolver.resolve("self")
	assert_eq(self_target.kind, DebugTarget.Kind.ENTITY)
	assert_eq(self_target.entity, player)

	var interaction_target: DebugTarget = DebugTargetResolver.resolve("target")
	assert_eq(interaction_target.kind, DebugTarget.Kind.PACKAGE)
	assert_eq(interaction_target.entity, parcel)

	for query: String in [
		identity.package_id,
		"pkg:" + identity.package_id,
		"#1",
		"#001",
		"entity:" + String(parcel.id),
	]:
		var resolved: DebugTarget = DebugTargetResolver.resolve(query)
		assert_eq(resolved.kind, DebugTarget.Kind.PACKAGE, query)
		assert_eq(resolved.package_id, identity.package_id, query)

	var visit_query: String = "visit:" + String(visit.visit_id)
	var visit_target: DebugTarget = DebugTargetResolver.resolve(visit_query)
	assert_eq(visit_target.kind, DebugTarget.Kind.VISIT, visit_query)
	assert_eq(visit_target.package_id, identity.package_id, visit_query)
	assert_eq(visit_target.visit, visit, visit_query)

	var entity_query: String = "entity:" + String(parcel.id)
	record.active = false
	_world.remove_entity(parcel)
	assert_eq(DebugTargetResolver.resolve("#001").kind, DebugTarget.Kind.INVALID)
	assert_eq(DebugTargetResolver.resolve(entity_query).kind, DebugTarget.Kind.INVALID)

	var historical: DebugTarget = DebugTargetResolver.resolve(identity.package_id)
	assert_eq(historical.kind, DebugTarget.Kind.PACKAGE)
	assert_null(historical.entity)
	assert_eq(historical.visit, visit)


func test_customer_debug_service_keeps_actual_declaration_complaint_and_feedback_distinct() -> void:
	_create_core_world()
	var delivered: CustomerVisit = _add_visit("debug:customer:delivered")
	var delivered_target: DebugTarget = DebugTargetResolver.resolve(delivered.package_id)

	var actual_result: DebugServiceResult = DebugCustomerService.set_actual(
		delivered_target,
		CustomerVisit.Actual.DELIVERED,
	)
	assert_true(actual_result.success)
	assert_eq(delivered.actual, CustomerVisit.Actual.DELIVERED)
	assert_eq(delivered.declaration, CustomerVisit.Declaration.NONE)

	var declaration_result: DebugServiceResult = DebugCustomerService.declare(
		delivered_target,
		CustomerVisit.Declaration.TAKEN,
	)
	assert_true(declaration_result.success)
	assert_eq(delivered.actual, CustomerVisit.Actual.DELIVERED)
	assert_eq(delivered.declaration, CustomerVisit.Declaration.TAKEN)
	assert_true(delivered.settlement_committed)
	assert_false(
		DebugCustomerService.set_actual(
			delivered_target,
			CustomerVisit.Actual.NOT_RESOLVED,
		).success
	)

	var disputed: CustomerVisit = _add_visit("debug:customer:disputed")
	var disputed_target: DebugTarget = DebugTargetResolver.resolve(disputed.package_id)
	var complaint_result: DebugServiceResult = DebugCustomerService.complaint(
		disputed_target,
		CustomerComplaint.Reason.NOT_DELIVERED,
		false,
	)
	assert_true(complaint_result.success)
	assert_not_null(disputed.complaint)
	assert_eq(disputed.complaint.reason, CustomerComplaint.Reason.NOT_DELIVERED)
	assert_eq(disputed.complaint.outcome, CustomerComplaint.Outcome.PENDING)
	assert_true(
		DebugCustomerService.complaint(
			disputed_target,
			CustomerComplaint.Reason.NOT_DELIVERED,
			false,
		).success
	)
	assert_false(
		DebugCustomerService.complaint(
			disputed_target,
			CustomerComplaint.Reason.DAMAGED,
			false,
		).success
	)
	assert_true(DebugCustomerService.resolve_complaint(disputed_target).success)
	assert_ne(disputed.complaint.outcome, CustomerComplaint.Outcome.PENDING)

	var approved: CustomerVisit = _add_visit("debug:customer:approved")
	var approved_target: DebugTarget = DebugTargetResolver.resolve(approved.package_id)
	assert_true(DebugCustomerService.approve(approved_target, 73).success)
	assert_eq(approved.feedback, CustomerVisit.Feedback.APPROVED)
	assert_eq(approved.satisfaction, 73)
	assert_eq(approved.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(approved.declaration, CustomerVisit.Declaration.NONE)
	assert_false(DebugCustomerService.approve(approved_target, 101).success)


func test_debug_economy_is_journaled_idempotent_and_reversible() -> void:
	_create_core_world()
	assert_true(DebugEconomyService.credit(100, "stage9_credit").success)
	assert_true(DebugEconomyService.debit(40, "stage9_debit").success)
	assert_true(DebugEconomyService.penalty(30, "stage9_penalty").success)
	assert_true(DebugEconomyService.reverse_penalty(10, "stage9_reversal").success)

	assert_eq(_wallet.balance, 40)
	assert_eq(_wallet.penalties, 20)
	assert_eq(DebugEconomyService.manual_penalty_outstanding(_wallet), 20)
	assert_eq(_wallet.operations.size(), 4)

	var ids: Dictionary[StringName, bool] = {}
	for operation: MoneyOperation in _wallet.operations:
		assert_false(ids.has(operation.operation_id))
		ids[operation.operation_id] = true
		assert_true(String(operation.operation_id).begins_with("debug/1/"))

	var balance_before_duplicate: int = _wallet.balance
	var duplicate: MoneyOperation = _wallet.operations[0].duplicate(true) as MoneyOperation
	assert_eq(WalletService.submit(duplicate), WalletService.Status.DUPLICATE)
	assert_eq(_wallet.balance, balance_before_duplicate)

	assert_false(DebugEconomyService.reverse_penalty(21, "too_much").success)
	assert_eq(_wallet.balance, balance_before_duplicate)
	assert_eq(_wallet.penalties, 20)


func test_package_debug_service_and_health_lifecycle_use_real_domain_boundaries() -> void:
	_level = MAIN_LEVEL.instantiate() as Node3D
	add_child(_level)
	_level.set_physics_process(false)
	await get_tree().physics_frame

	var definition_keys: PackedStringArray = DebugPackageService.definition_keys()
	assert_false(definition_keys.is_empty())
	var spawn_result: DebugServiceResult = DebugPackageService.spawn(
		StringName(definition_keys[0]),
		1,
		DebugPackageService.MODE_SELF,
		false,
	)
	assert_true(spawn_result.success)

	var spawned: Array[Entity] = _debug_packages()
	assert_eq(spawned.size(), 1)
	var parcel: Entity = spawned[0]
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var target: DebugTarget = DebugTargetResolver.resolve(identity.package_id)
	assert_eq(target.kind, DebugTarget.Kind.PACKAGE)
	assert_eq(target.entity, parcel)

	var register_result: DebugServiceResult = DebugPackageService.register(target)
	assert_true(register_result.success)
	target = DebugTargetResolver.resolve(identity.package_id)
	assert_not_null(target.registration)
	assert_gt(target.registration.number, 0)
	var registration_number: int = target.registration.number
	assert_eq(
		DebugTargetResolver.resolve("#%03d" % registration_number).package_id,
		identity.package_id,
	)

	var remove_result: DebugServiceResult = DebugPackageService.remove(target)
	assert_true(remove_result.success)
	assert_false(EntityAvailability.contains(parcel, ECS.world))
	var historical: DebugTarget = DebugTargetResolver.resolve("#%03d" % registration_number)
	assert_eq(historical.kind, DebugTarget.Kind.PACKAGE)
	assert_null(historical.entity)
	assert_true(historical.registration.active)

	var session: Entity = _level.get_node("Entityes/DaySession") as Entity
	session.remove_component(C_CustomerFlow)
	var player_target: DebugTarget = DebugTargetResolver.resolve("self")
	var player: Entity = player_target.entity
	var health: C_Health = player.get_component(C_Health) as C_Health
	assert_not_null(health)
	var original_health: float = health.current
	assert_gt(original_health, 5.0)

	assert_true(
		DebugHealthService.apply_damage(
			player_target,
			5.0,
			DamageRequest.Type.GENERIC,
		).success
	)
	_process_gameplay(2)
	assert_almost_eq(health.current, original_health - 5.0, 0.001)

	assert_true(DebugHealthService.heal(player_target, 5.0).success)
	_process_gameplay(2)
	assert_almost_eq(health.current, original_health, 0.001)

	assert_true(DebugHealthService.kill(player_target).success)
	_process_gameplay(2)
	assert_true(health.depleted)
	assert_almost_eq(health.current, 0.0, 0.001)
	assert_false(DebugHealthService.heal(player_target, 1.0).success)

	var reset_result: DebugServiceResult = DebugHealthService.reset(player_target)
	assert_true(reset_result.success)
	assert_false(health.depleted)
	assert_almost_eq(health.current, health.value, 0.001)
	assert_false(player.has_component(C_Death))
