extends GutTest
## Native counter support, source selection and stale-offer rejection use the real delivery owner.

const PARCEL: PackedScene = preload("res://content/domains/packages/entities/package_a.tscn")
const CUSTOMER: PackedScene = preload("res://content/domains/customers/entities/customer.tscn")
const COUNTER: PackedScene = preload(
	"res://content/domains/customers/entities/delivery_counter.tscn"
)

var _world: World
var _actor: E_RigidBodyCharacter
var _customer: E_NpcCharacter
var _station: E_DeliveryCounter
var _visit: CustomerVisit
var _flow: C_CustomerFlow
var _cycle: C_DayCycle


#region Native fixture
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_GrabLifecycle.new())
	_world.add_observer(O_PhysicalSlotLifecycle.new())
	var session: Entity = Entity.new()
	session.component_resources = [C_CustomerFlow.new(), C_DayCycle.new(), C_PackageLedger.new()]
	_world.add_entity(session)
	_flow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.DAY
	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_RigidBodyCharacter)
	body.freeze = true
	body.position = Vector3(0, 0, 3)
	_actor = body as Node as E_RigidBodyCharacter
	var anchor: Marker3D = Marker3D.new()
	anchor.position = Vector3(0, 1.3, -0.5)
	body.add_child(anchor)
	_actor.hold_anchor = anchor
	_actor.head_axis_x = anchor
	_actor.component_resources = [
		C_PlayerInputController.new(),
		C_Controller.new(),
		C_GrabControl.new(),
		C_CarryLoad.new(),
		C_Strength.new(),
		C_Motion.new(),
		C_Health.new(),
	]
	_world.add_entity(_actor)
	(_actor.get_component(C_Health) as C_Health).current = 10.0
	_station = COUNTER.instantiate() as E_DeliveryCounter
	EntityCompositionFixture.register(_world, _station)
	_visit = _new_visit(&"visit/main", "parcel/own")
	_customer = _receiver(_visit, Vector3(0, 0, 1.2))


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	await get_tree().process_frame


func _new_visit(id: StringName, package_id: String) -> CustomerVisit:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = id
	visit.package_id = package_id
	visit.definition = DEF_Customer.new()
	visit.started = true
	_flow.visits.append(visit)
	return visit


func _receiver(visit: CustomerVisit, position: Vector3) -> E_NpcCharacter:
	var customer: E_NpcCharacter = CUSTOMER.instantiate() as E_NpcCharacter
	var body: RigidBody3D = customer as Node as RigidBody3D
	body.freeze = true
	body.position = position
	EntityCompositionFixture.register_visit(_world, customer, visit)
	(customer.get_component(C_CustomerAgent) as C_CustomerAgent).phase = (
		C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	)
	return customer


func _parcel(id: String = "parcel/own", position: Vector3 = Vector3(0, 1.1, 0)) -> E_Package:
	var parcel: E_Package = PARCEL.instantiate() as E_Package
	parcel.package_id = id
	var body: RigidBody3D = parcel as Node as RigidBody3D
	body.position = position
	var collision: CollisionShape3D = parcel.get_node("CollisionShape3D") as CollisionShape3D
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.4
	collision.shape = shape
	collision.transform = Transform3D.IDENTITY
	EntityCompositionFixture.register(_world, parcel)
	(parcel.get_component(C_PackageState) as C_PackageState).registration = (
		C_PackageState.Registration.REGISTERED
	)
	if id == _visit.package_id:
		CustomerParcelAssignment.bind_parcel(_customer, _visit)
	body.sleeping = true
	return parcel


func _sync_physics() -> void:
	# One step integrates new bodies; the following flush publishes Area overlap notifications.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _offer() -> CustomerParcelOffer:
	return CustomerHandoffService.select_offer(_actor, _customer, _visit)


func _assert_unresolved(parcel: Entity) -> void:
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.NONE)
	assert_true(EntityAvailability.contains(parcel, _world))
#endregion


#region Counter source and the scheduled entry point
func test_real_falling_parcel_becomes_an_offer_only_after_landing_and_settling() -> void:
	var parcel: E_Package = _parcel("parcel/own", Vector3(0, 1.7, 0))
	var body: RigidBody3D = parcel as Node as RigidBody3D
	body.sleeping = false
	await _sync_physics()
	assert_null(_offer())
	var offer: CustomerParcelOffer = null
	for physics_step: int in 90:
		await _sync_physics()
		offer = _offer()
		if offer != null:
			break
	assert_not_null(
		offer,
		"Native settle: position=%s linear=%s angular=%s in_area=%s"
		% [
			body.global_position,
			body.linear_velocity,
			body.angular_velocity,
			_station.parcels().has(parcel),
		],
	)
	if offer != null:
		assert_eq(CustomerFlowService.confirm_offer(offer), PackageDeliveryCheck.Result.READY)
		assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)


func test_waiting_scheduler_takes_resting_counter_parcel_once_without_f() -> void:
	var parcel: E_Package = _parcel()
	await _sync_physics()
	assert_has(_station.parcels(), parcel)
	var offer: CustomerParcelOffer = _offer()
	assert_not_null(offer)
	if offer == null:
		return
	assert_eq(offer.source, CustomerParcelOffer.Source.COUNTER)
	CustomerFlowFixture.advance(_flow, _cycle, 0.0)
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.NONE)
	assert_false(EntityAvailability.contains(parcel, _world))
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	assert_eq(CustomerFlowService.confirm_offer(offer), PackageDeliveryCheck.Result.MISSING)


func test_area_overlap_without_support_or_with_velocity_is_not_an_offer() -> void:
	var parcel: E_Package = _parcel("parcel/own", Vector3(0, 1.5, 0))
	await _sync_physics()
	assert_has(_station.parcels(), parcel)
	assert_null(_offer(), "A motionless apex above the desk is still unsupported")
	var body: RigidBody3D = parcel as Node as RigidBody3D
	body.position.y = 1.1
	await _sync_physics()
	body.linear_velocity = Vector3(2, 0, 0)
	assert_null(_offer())
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3(0, 2, 0)
	assert_null(_offer())
	_assert_unresolved(parcel)


func test_motionless_parcel_just_above_contact_tolerance_is_not_supported() -> void:
	var parcel: E_Package = _parcel("parcel/own", Vector3(0, 1.125, 0))
	await _sync_physics()
	assert_has(_station.parcels(), parcel)
	assert_null(_offer(), "A two-centimetre gap is outside the authored one-centimetre tolerance")
	_assert_unresolved(parcel)


func test_held_parcel_over_counter_has_only_the_held_source() -> void:
	var parcel: E_Package = _parcel()
	await _sync_physics()
	assert_has(_station.parcels(), parcel)
	(parcel as Node as RigidBody3D).freeze = false
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	assert_null(
		CustomerHandoffService.select_offer(
			_actor,
			_customer,
			_visit,
			true,
			CustomerParcelOffer.Source.COUNTER,
		)
	)
	var offer: CustomerParcelOffer = _offer()
	assert_not_null(offer)
	if offer != null:
		assert_eq(offer.source, CustomerParcelOffer.Source.HELD)
		assert_eq(CustomerFlowService.confirm_offer(offer), PackageDeliveryCheck.Result.READY)
	assert_null(GrabQueries.held_object(_actor))
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)


func test_accessible_own_counter_box_precedes_a_closer_wrong_box() -> void:
	var wrong: E_Package = _parcel("parcel/wrong", Vector3(-0.3, 1.1, 0.2))
	var own: E_Package = _parcel("parcel/own", Vector3(0.3, 1.1, -0.2))
	await _sync_physics()
	var offer: CustomerParcelOffer = _offer()
	assert_not_null(offer)
	if offer == null:
		return
	assert_same(offer.parcel, own)
	assert_eq(CustomerFlowService.confirm_offer(offer), PackageDeliveryCheck.Result.READY)
	assert_true(EntityAvailability.contains(wrong, _world))
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)


func test_stable_stack_is_supported_through_the_lower_parcel_to_the_counter() -> void:
	_parcel("parcel/support")
	var top: E_Package = _parcel("parcel/own", Vector3(0, 1.5, 0))
	_customer.hold_anchor.position.y = 1.4
	await _sync_physics()
	var offer: CustomerParcelOffer = _offer()
	assert_not_null(offer)
	if offer != null:
		assert_same(offer.parcel, top)
		assert_eq(offer.check.result, PackageDeliveryCheck.Result.READY)


func test_wrong_candidate_tie_uses_stable_package_id_and_commits_no_delivery() -> void:
	_parcel("wrong/b", Vector3(0.3, 1.1, 0))
	var first: E_Package = _parcel("wrong/a", Vector3(-0.3, 1.1, 0))
	await _sync_physics()
	for attempt: int in 3:
		var offer: CustomerParcelOffer = _offer()
		assert_not_null(offer)
		if offer != null:
			assert_same(offer.parcel, first)
			assert_eq(offer.check.result, PackageDeliveryCheck.Result.WRONG_PACKAGE)
			assert_eq(
				CustomerFlowService.confirm_offer(offer),
				PackageDeliveryCheck.Result.WRONG_PACKAGE,
			)
	_assert_unresolved(first)
#endregion


#region Revalidation and existing delivery behavior
func test_replaced_role_or_visit_rejects_a_previously_valid_receipt() -> void:
	var parcel: E_Package = _parcel()
	await _sync_physics()
	var offer: CustomerParcelOffer = _offer()
	assert_not_null(offer)
	var agent: C_CustomerAgent = C_CustomerAgent.new()
	agent.visit_id = _visit.visit_id
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_customer.add_component(agent)
	assert_eq(CustomerFlowService.confirm_offer(offer), PackageDeliveryCheck.Result.MISSING)
	offer = _offer()
	assert_not_null(offer)
	_flow.visits[0] = _visit.duplicate() as CustomerVisit
	assert_eq(CustomerFlowService.confirm_offer(offer), PackageDeliveryCheck.Result.MISSING)
	_assert_unresolved(parcel)


func test_moved_or_newly_held_counter_parcel_rejects_the_old_receipt() -> void:
	var parcel: E_Package = _parcel()
	await _sync_physics()
	var offer: CustomerParcelOffer = _offer()
	assert_not_null(offer)
	(parcel as Node as Node3D).position.x = 3.0
	assert_eq(CustomerFlowService.confirm_offer(offer), PackageDeliveryCheck.Result.MISSING)
	(parcel as Node as Node3D).position.x = 0.0
	await _sync_physics()
	offer = _offer()
	assert_not_null(offer)
	(parcel as Node as RigidBody3D).freeze = false
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	assert_eq(CustomerFlowService.confirm_offer(offer), PackageDeliveryCheck.Result.MISSING)
	assert_same(GrabQueries.held_object(_actor), parcel)
	_assert_unresolved(parcel)


func test_counter_reservation_blocks_another_ready_receiver_until_release() -> void:
	var parcel: E_Package = _parcel()
	var other_visit: CustomerVisit = _new_visit(&"visit/other", "other/own")
	var other: E_NpcCharacter = _receiver(other_visit, Vector3(0.5, 0, 1.2))
	var reservation: R_NpcServiceAt = R_NpcServiceAt.new()
	reservation.visit_id = other_visit.visit_id
	var link: Relationship = Relationship.new(reservation, _station)
	other.add_relationship(link)
	await _sync_physics()
	assert_same(CustomerFlowQueries.waiting_customer(_station), other)
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_assert_unresolved(parcel)
	other.remove_relationship(link)
	(other.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.LEAVING
	assert_same(CustomerFlowQueries.waiting_customer(_station), _customer)
	assert_true(CustomerFlowService.try_automatic_handoff(_customer, _visit))


func test_manual_counter_uses_the_same_offer_gate_when_automatic_mode_is_disabled() -> void:
	var parcel: E_Package = _parcel()
	_visit.definition.automatic_handoff = false
	await _sync_physics()
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_assert_unresolved(parcel)
	assert_eq(CustomerFlowService.confirm_delivery(_station), PackageDeliveryCheck.Result.READY)
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)


func test_counter_offer_starts_existing_booth_inspection_without_finishing_order() -> void:
	var parcel: E_Package = _parcel()
	_visit.definition.private_inspection = true
	var booth: Entity = (
		load("res://content/domains/customers/entities/inspection_booth.tscn") as PackedScene
	).instantiate() as Entity
	(booth as Node as Node3D).position.x = 4.0
	_world.add_entity(booth)
	await _sync_physics()
	assert_true(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	assert_eq(CustomerInspectionQueries.owner_for(parcel), _customer)
	assert_eq(
		(_customer.get_component(C_CustomerAgent) as C_CustomerAgent).phase,
		C_CustomerAgent.Phase.GOING_TO_BOOTH,
	)
	_assert_unresolved(parcel)
	assert_null(_offer())
#endregion
