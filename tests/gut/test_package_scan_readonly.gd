extends GutTest
## Real hand/ray scanning reads receiving-owned registration without allocating or publishing it.


class RegistrationEvents extends Observer:
	## Number of actual registration facts observed in this fixture's World.
	var count: int = 0


	func query() -> QueryBuilder:
		return q.on_event(PackageScanResult.EVENT)


	func each(_event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		count += 1


var _world: World
var _holder: Entity
var _scanner: E_Scanner
var _parcel: E_Package
var _events: RegistrationEvents


#region Native isolated scanner setup
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_GrabLifecycle.new())
	_events = RegistrationEvents.new()
	_world.add_observer(_events)
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_PackageLedger.new()]
	_world.add_entity(session)
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_RigidBodyCharacter)
	body.freeze = true
	_holder = body as Node as Entity
	var hand: Marker3D = Marker3D.new()
	hand.position = Vector3(0.5, 1.0, -0.4)
	body.add_child(hand)
	var ray: RayCast3D = RayCast3D.new()
	ray.position.y = 1.0
	body.add_child(ray)
	_holder.set("interaction_ray_cast", ray)
	_holder.set("right_hand_slot", hand)
	_holder.component_resources = [
		C_Interactor.new(),
		C_GrabControl.new(),
		C_CarryLoad.new(),
		C_Strength.new(),
	]
	_world.add_entity(_holder)
	_scanner = (
		load("res://content/domains/packages/entities/scanner.tscn") as PackedScene
	).instantiate() as E_Scanner
	(_scanner as Node as RigidBody3D).position = Vector3(0.5, 1.0, -0.4)
	EntityCompositionFixture.register(_world, _scanner)
	var grip: R_HeldBy = R_HeldBy.new()
	grip.slot = C_Grabbable.HoldSlot.RIGHT_HAND
	_scanner.add_relationship(Relationship.new(grip, _holder))
	_parcel = (
		load("res://content/domains/packages/entities/package.tscn") as PackedScene
	).instantiate() as E_Package
	_parcel.package_id = "scan/received"
	var supply: DEF_Delivery = load(
		"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
	) as DEF_Delivery
	_parcel.package_definition = supply.packages[0]
	var parcel_body: RigidBody3D = _parcel as Node as RigidBody3D
	parcel_body.position = Vector3(0.0, 1.0, -1.8)
	parcel_body.freeze = true
	EntityCompositionFixture.register(_world, _parcel)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Imported box origin is at its base; aim at the authored collider instead of grazing its floor.
	ray.look_at((_parcel.get_node("CollisionShape3D") as CollisionShape3D).global_position)
	assert_true(grip.lifecycle_applied, "Scanner has a real applied hand relationship")
	var target: Entity = InteractionTargetingGeometry.find_target(
		_holder,
		_holder.get_component(C_Interactor) as C_Interactor,
	)
	assert_same(target, _parcel, "The real interaction ray reaches the parcel")
	assert_true(PackageRegistrationService.can_scan(_holder, _scanner, _parcel))


func after_each() -> void:
	GrabReleaseService.release(_holder, _scanner, false)
	_world.purge(false)
	_world.free()
	ECS.world = null
#endregion


#region Real scanner reads
func test_repeated_scanning_preserves_number_date_history_and_registration_fact() -> void:
	assert_eq(
		PackageRegistrationService.register_package(_parcel).outcome,
		PackageScanResult.Outcome.REGISTERED,
	)
	var state: C_PackageState = _parcel.get_component(C_PackageState) as C_PackageState
	assert_eq(state.scan, C_PackageState.Scan.NOT_SCANNED)
	var record: PackageRegistrationRecord = PackageQueries.ledger().records[0]
	var history: String = record.history_id
	DayPhaseQueries.current().day_index = 2
	for attempt: int in 2:
		var receipt: PackageScanResult = PackageRegistrationService.scan(_holder, _scanner, _parcel)
		assert_eq(receipt.outcome, PackageScanResult.Outcome.ALREADY_REGISTERED)
		assert_eq(receipt.number, 1)
	assert_eq(state.scan, C_PackageState.Scan.SCANNED)
	assert_eq(state.registration, C_PackageState.Registration.REGISTERED)
	assert_eq(state.registration_number, 1)
	assert_eq(state.registration_day, 1)
	assert_eq(record.day_index, 1)
	assert_eq(record.received_day, 1)
	assert_eq(record.history_id, history)
	assert_eq(PackageQueries.ledger().records.size(), 1)
	assert_eq(_events.count, 1)
	assert_eq(PackageRegistrationService.smallest_free_number(PackageQueries.ledger()), 2)


func test_scanning_an_unregistered_receipt_cannot_allocate_its_number() -> void:
	var record: PackageRegistrationRecord = PackageHistoryService.record_arrival(_parcel, 1)
	var receipt: PackageScanResult = PackageRegistrationService.scan(_holder, _scanner, _parcel)
	assert_eq(receipt.outcome, PackageScanResult.Outcome.REJECTED)
	assert_eq(record.number, 0)
	assert_eq(record.day_index, 0)
	assert_eq(_events.count, 0)
	assert_eq(
		(_parcel.get_component(C_PackageState) as C_PackageState).scan,
		C_PackageState.Scan.NOT_SCANNED,
	)
#endregion
