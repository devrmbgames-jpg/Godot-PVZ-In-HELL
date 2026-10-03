extends RefCounted
## Проверяет близость, управление и готовность автоприёма без изменения владения.
class_name CustomerHandoffService

const FALLBACK_EYE_HEIGHT: float = 1.3
const OCCLUSION_MASK: int = 31


## CustomerFlow передаёт назначение из Relationship и сам выполняет обычную выдачу.
static func can_receive(actor: Entity, customer: E_Customer, visit: CustomerVisit, parcel: Entity, assigned: bool) -> bool:
	if visit == null or visit.definition == null or visit.finished or visit.actual != CustomerVisit.Actual.NOT_RESOLVED or not visit.definition.automatic_handoff:
		return false
	if not GrabService.holder_available(customer) or customer.has_component(C_Death):
		return false
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or agent.visit_id != visit.visit_id or agent.phase not in [C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE]:
		return false
	if not GrabService.holder_available(actor) or actor.has_component(C_Death) or bool(Console.is_visible()):
		return false
	if InteractionControlFocus.current(actor) > InteractionControlFocus.Priority.CARRY:
		return false
	var actor_body: Node3D = actor as Node as Node3D
	var customer_body: Node3D = customer as Node as Node3D
	var distance: float = visit.definition.automatic_handoff_distance
	if actor_body == null or customer_body == null or not is_finite(distance) or distance <= 0.0 or actor_body.global_position.distance_squared_to(customer_body.global_position) > distance * distance:
		return false
	if not GrabService.entity_available(parcel) or CustomerInspectionService.owner_for(parcel) != null:
		return false
	var check: PackageDeliveryCheck = CustomerOutcomeService.check(
		visit, parcel.get_component(C_Package) as C_Package,
		parcel.get_component(C_PackageState) as C_PackageState,
		assigned, true, true,
	)
	if check.result != PackageDeliveryCheck.Result.READY or not _has_line_of_sight(actor, customer):
		return false
	return true


static func _has_line_of_sight(actor: Entity, customer: E_Customer) -> bool:
	var player: E_PhysicalCharacter = actor as E_PhysicalCharacter
	var actor_body: Node3D = actor as Node as Node3D
	var customer_body: Node3D = customer as Node as Node3D
	var start: Vector3 = player.head_axis_x.global_position if player != null and is_instance_valid(player.head_axis_x) else actor_body.global_position + Vector3.UP * FALLBACK_EYE_HEIGHT
	var end: Vector3 = customer.head_axis_x.global_position if is_instance_valid(customer.head_axis_x) else customer_body.global_position + Vector3.UP * FALLBACK_EYE_HEIGHT
	var excluded: Array[RID] = []
	for entity: Entity in [actor, customer]:
		var body: CollisionObject3D = entity as Node as CollisionObject3D
		if body != null:
			excluded.append(body.get_rid())
	for slot: int in 3:
		var held_body: RigidBody3D = GrabService.physical_body(GrabService.held_in_slot(actor, slot))
		if held_body != null:
			excluded.append(held_body.get_rid())
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end, OCCLUSION_MASK, excluded)
	ray.hit_from_inside = true
	return customer_body.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
