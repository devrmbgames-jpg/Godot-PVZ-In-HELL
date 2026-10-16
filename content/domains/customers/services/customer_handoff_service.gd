extends RefCounted
## Проверяет близость, управление и готовность автоприёма без изменения владения.
class_name CustomerHandoffService

const OCCLUSION_MASK: int = 31


#region Условия автоприёма
## CustomerFlow передаёт назначение из Relationship и сам выполняет обычную выдачу.
static func can_receive(
	actor: Entity,
	customer: E_NpcCharacter,
	visit: CustomerVisit,
	parcel: Entity,
	assigned: bool,
) -> bool:
	if (
		visit == null or visit.definition == null or visit.finished
		or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
		or not visit.definition.automatic_handoff
	):
		return false
	if (
		not GrabQueries.holder_available(customer) or customer.has_component(C_Death)
		or (customer as Node).get_tree().paused
	):
		return false

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if (
		agent == null or agent.visit_id != visit.visit_id
		or agent.phase
		not in [C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE]
	):
		return false
	if (
		not GrabQueries.holder_available(actor)
		or actor.has_component(C_Death) or bool(Console.is_visible())
	):
		return false
	if InteractionControlFocus.current(actor) > InteractionControlFocus.Priority.CARRY:
		return false

	if (
		not GrabQueries.entity_available(parcel)
		or CustomerInspectionQueries.owner_for(parcel) != null
	):
		return false
	var grip: Relationship = GrabQueries.held_relationship(parcel)
	if grip == null or grip.target != actor:
		return false
	var anchor: Node3D = GrabQueries.hold_anchor(customer)
	var body: RigidBody3D = GrabQueries.physical_body(parcel)
	var distance: float = visit.definition.automatic_handoff_distance
	if anchor == null or not is_finite(distance) or distance <= 0.0:
		return false
	distance = minf(distance, CustomerHandoffGeometry.MAX_REACH_METERS)
	var origin: Vector3 = anchor.global_position
	var surface: Vector3 = CustomerHandoffGeometry.closest_point(body, origin)
	if not surface.is_finite() or origin.distance_squared_to(surface) >= distance * distance:
		return false

	var check: PackageDeliveryCheck = CustomerOutcomeService.check(
		visit,
		parcel.get_component(C_Package) as C_Package,
		parcel.get_component(C_PackageState) as C_PackageState,
		assigned,
		true,
		true,
	)
	if check.result != PackageDeliveryCheck.Result.READY or not _has_line_of_sight(
		actor, customer, body, origin, surface,
	):
		return false
	return true

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
