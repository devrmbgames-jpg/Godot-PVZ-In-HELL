extends RefCounted
## Selects and revalidates transient parcel offers; ownership and outcomes stay with their owners.
class_name CustomerHandoffService

const OCCLUSION_MASK: int = 31
## Millimetre ranking buckets avoid source-order changes from tiny native contact jitter.
## Eligibility still uses the exact strict reach threshold.
const SORT_DISTANCE_UNITS_PER_METER: float = 1000.0


#region Offer selection and revalidation
## Compatibility query for an actual held parcel; assignment is always checked against live links.
static func can_receive(
	actor: Entity,
	customer: E_NpcCharacter,
	visit: CustomerVisit,
	parcel: Entity,
	assigned: bool,
) -> bool:
	if not assigned:
		return false
	var offer: CustomerParcelOffer = _offer(actor, customer, visit, parcel, null)
	return evaluate_offer(offer, true).result == PackageDeliveryCheck.Result.READY


## Selects one reachable own parcel before a wrong one, then distance and stable package ID.
## Sources are mutually exclusive: a held parcel is never also a counter offer.
static func select_offer(
	actor: Entity, customer: E_NpcCharacter, visit: CustomerVisit,
	automatic: bool = true, sources: int = CustomerParcelOffer.ALL_SOURCES,
	station: E_DeliveryCounter = null,
) -> CustomerParcelOffer:
	if not EntityAvailability.contains(customer, ECS.world):
		return null
	var offers: Array[CustomerParcelOffer] = []
	if sources & CustomerParcelOffer.Source.HELD:
		for slot: int in [
			C_Grabbable.HoldSlot.CARRY, C_Grabbable.HoldSlot.RIGHT_HAND,
			C_Grabbable.HoldSlot.LEFT_HAND,
		]:
			var parcel: Entity = GrabQueries.held_in_slot(actor, slot)
			if parcel != null and parcel.has_component(C_Package):
				_append_offer(offers, _offer(actor, customer, visit, parcel, null), automatic)
	if sources & CustomerParcelOffer.Source.COUNTER:
		if station == null:
			station = CustomerFlowQueries.counter()
		if station != null and CustomerFlowQueries.waiting_customer(station) == customer:
			for parcel: Entity in station.parcels():
				_append_offer(offers, _offer(actor, customer, visit, parcel, station), automatic)
	offers.sort_custom(_offer_before)
	return offers[0] if not offers.is_empty() else null


## Rechecks the exact World, role, visit, physical source and assignment before synchronous commit.
## The captured check/score is advisory; an old receipt never grants permission to hand over.
static func evaluate_offer(
	offer: CustomerParcelOffer, automatic: bool = true,
) -> PackageDeliveryCheck:
	var missing: PackageDeliveryCheck = PackageDeliveryCheck.new()
	if offer == null or offer.world != ECS.world:
		return missing
	var customer: E_NpcCharacter = offer.customer
	var visit: CustomerVisit = offer.visit
	if (
		not GrabQueries.holder_available(customer) or customer.has_component(C_Death)
		or (customer as Node).get_tree().paused
		or customer.get_component(C_CustomerAgent) != offer.agent or offer.agent == null
		or visit == null or CustomerFlowQueries.find_visit(visit.visit_id) != visit
		or visit.definition == null or visit.finished or offer.agent.visit_id != visit.visit_id
		or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
		or offer.agent.phase not in [
			C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE,
		]
		or (automatic and not visit.definition.automatic_handoff)
		or NpcDeliveryScenarioService.armed_for(customer as E_DistrictNpc) != null
	):
		return missing
	var actor: Entity = offer.actor
	if (
		not GrabQueries.holder_available(actor) or actor.has_component(C_Death)
		or bool(Console.is_visible())
		or InteractionControlFocus.current(actor) > InteractionControlFocus.Priority.CARRY
	):
		return missing
	var parcel: Entity = offer.parcel
	if (
		not _parcel_available(parcel) or not parcel.has_component(C_Package)
	):
		return missing
	if offer.source == CustomerParcelOffer.Source.HELD:
		var grip: Relationship = GrabQueries.held_relationship(parcel)
		if grip == null or grip.target != actor:
			return missing
		var slot: int = (grip.relation as R_HeldBy).slot
		if slot not in [
			C_Grabbable.HoldSlot.CARRY, C_Grabbable.HoldSlot.RIGHT_HAND,
			C_Grabbable.HoldSlot.LEFT_HAND,
		] or GrabQueries.held_in_slot(actor, slot) != parcel:
			return missing
	elif offer.source == CustomerParcelOffer.Source.COUNTER:
		if not _counter_source_available(offer):
			return missing
	else:
		return missing
	var anchor: Node3D = GrabQueries.hold_anchor(customer)
	var body: RigidBody3D = GrabQueries.physical_body(parcel)
	var distance: float = visit.definition.automatic_handoff_distance
	if anchor == null or not is_finite(distance) or distance <= 0.0:
		return missing
	distance = minf(distance, CustomerHandoffGeometry.MAX_REACH_METERS)
	var origin: Vector3 = anchor.global_position
	var surface: Vector3 = CustomerHandoffGeometry.closest_point(body, origin)
	if not surface.is_finite() or origin.distance_squared_to(surface) >= distance * distance:
		return missing
	if not _has_line_of_sight(actor, customer, body, origin, surface):
		return missing
	return CustomerOutcomeService.check(
		visit,
		parcel.get_component(C_Package) as C_Package,
		parcel.get_component(C_PackageState) as C_PackageState,
		CustomerFlowQueries.assigned(parcel, customer, visit),
		offer.source == CustomerParcelOffer.Source.HELD,
		offer.source == CustomerParcelOffer.Source.HELD,
	)


static func _offer(
	actor: Entity, customer: E_NpcCharacter, visit: CustomerVisit, parcel: Entity,
	station: E_DeliveryCounter,
) -> CustomerParcelOffer:
	var offer: CustomerParcelOffer = CustomerParcelOffer.new()
	offer.world = ECS.world
	offer.actor = actor
	offer.customer = customer
	offer.agent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	offer.visit = visit
	offer.parcel = parcel
	offer.counter = station
	offer.source = (
		CustomerParcelOffer.Source.COUNTER if station != null else CustomerParcelOffer.Source.HELD
	)
	return offer


static func _append_offer(
	offers: Array[CustomerParcelOffer], offer: CustomerParcelOffer, automatic: bool,
) -> void:
	offer.check = evaluate_offer(offer, automatic)
	if offer.check.result == PackageDeliveryCheck.Result.MISSING:
		return
	if automatic and offer.check.result not in [
		PackageDeliveryCheck.Result.READY, PackageDeliveryCheck.Result.WRONG_PACKAGE,
	]:
		return
	var origin: Vector3 = GrabQueries.hold_anchor(offer.customer).global_position
	var surface: Vector3 = CustomerHandoffGeometry.closest_point(
		GrabQueries.physical_body(offer.parcel), origin,
	)
	offer.distance_squared = origin.distance_squared_to(surface)
	offers.append(offer)


static func _offer_before(first: CustomerParcelOffer, second: CustomerParcelOffer) -> bool:
	var first_rank: int = _offer_rank(first.check.result)
	var second_rank: int = _offer_rank(second.check.result)
	if first_rank != second_rank:
		return first_rank < second_rank
	var first_distance: int = roundi(sqrt(first.distance_squared) * SORT_DISTANCE_UNITS_PER_METER)
	var second_distance: int = roundi(sqrt(second.distance_squared) * SORT_DISTANCE_UNITS_PER_METER)
	if first_distance != second_distance:
		return first_distance < second_distance
	var first_identity: C_Package = first.parcel.get_component(C_Package) as C_Package
	var second_identity: C_Package = second.parcel.get_component(C_Package) as C_Package
	return first_identity.package_id < second_identity.package_id


static func _offer_rank(result: PackageDeliveryCheck.Result) -> int:
	match result:
		PackageDeliveryCheck.Result.READY:
			return 0
		PackageDeliveryCheck.Result.WRONG_PACKAGE:
			return 1
		_:
			return 2
#endregion


#region Counter physical source
static func _parcel_available(parcel: Entity) -> bool:
	return (
		GrabQueries.entity_available(parcel)
		and CustomerInspectionQueries.owner_for(parcel) == null
		and PhysicalSlotService.relationship(parcel) == null
		and CartCargoQueries.relationship(parcel) == null
	)


static func _counter_source_available(offer: CustomerParcelOffer) -> bool:
	var station: E_DeliveryCounter = offer.counter
	if (
		not EntityAvailability.contains(station, ECS.world)
		or not station.has_component(C_DeliveryCounter)
		or CustomerFlowQueries.waiting_customer(station) != offer.customer
		or GrabQueries.held_relationship(offer.parcel) != null
	):
		return false
	var config: C_DeliveryCounter = station.get_component(C_DeliveryCounter) as C_DeliveryCounter
	if (
		not is_finite(config.settled_linear_speed_mps) or config.settled_linear_speed_mps < 0.0
		or not is_finite(config.settled_angular_speed_rps) or config.settled_angular_speed_rps < 0.0
		or not is_finite(config.support_tolerance_m) or config.support_tolerance_m <= 0.0
	):
		return false
	var parcels: Array[Entity] = station.parcels()
	if not parcels.has(offer.parcel):
		return false
	var stable: Array[RigidBody3D] = []
	for parcel: Entity in parcels:
		if not _parcel_available(parcel) or GrabQueries.held_relationship(parcel) != null:
			continue
		var body: RigidBody3D = GrabQueries.physical_body(parcel)
		if (
			body == null or body.freeze or not body.linear_velocity.is_finite()
			or not body.angular_velocity.is_finite()
		):
			continue
		if (
			body.linear_velocity.length_squared() > config.settled_linear_speed_mps ** 2
			or body.angular_velocity.length_squared() > config.settled_angular_speed_rps ** 2
		):
			continue
		stable.append(body)
	var offered_body: RigidBody3D = GrabQueries.physical_body(offer.parcel)
	return stable.has(offered_body) and CustomerHandoffGeometry.counter_supported(
		station as Node as PhysicsBody3D, offered_body, stable, config.support_tolerance_m,
		OCCLUSION_MASK,
	)
#endregion


#region Физическая видимость
static func _has_line_of_sight(
	actor: Entity, customer: E_NpcCharacter, parcel: RigidBody3D, start: Vector3, end: Vector3,
) -> bool:
	var excluded: Array[RID] = [parcel.get_rid()]
	for entity: Entity in [actor, customer]:
		var body: CollisionObject3D = entity as Node as CollisionObject3D
		if body != null:
			excluded.append(body.get_rid())
	var customer_body: Node3D = customer as Node as Node3D
	var space: PhysicsDirectSpaceState3D = customer_body.get_world_3d().direct_space_state
	if start.is_equal_approx(end):
		var point: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
		point.position = start
		point.collision_mask = OCCLUSION_MASK
		point.exclude = excluded
		return space.intersect_point(point, 1).is_empty()

	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		start,
		end,
		OCCLUSION_MASK,
		excluded,
	)
	ray.hit_from_inside = true
	return space.intersect_ray(ray).is_empty()

#endregion
