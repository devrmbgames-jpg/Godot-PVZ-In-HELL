extends RefCounted
## Проверяет физический доступ и публикует запрос вскрытия; состояние фиксирует наблюдатель.
class_name PackageOpening


#region Доступ и запрос вскрытия
## Проверяет луч взаимодействия либо удержание; клиент осмотра использует свой резерв и слот.
static func can_open(actor: Entity, package: Entity) -> bool:
	if not EntityAvailability.contains(actor, ECS.world):
		return false
	if not EntityAvailability.contains(package, ECS.world) or not package.has_component(C_Package):
		return false

	var condition: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	var interactable: C_Interactable = package.get_component(C_Interactable) as C_Interactable
	if condition == null or condition.opening == C_PackageState.Opening.OPENED:
		return false
	if condition.damage == C_PackageState.Damage.DESTROYED:
		return false
	if interactable == null or not interactable.enabled:
		return false

	var health: C_Health = actor.get_component(C_Health) as C_Health
	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	if health != null and (health.depleted or health.current <= 0.0):
		return false
	if motion != null and not motion.control_enabled:
		return false
	if actor is E_Customer:
		var agent: C_CustomerAgent = actor.get_component(C_CustomerAgent) as C_CustomerAgent
		var stored: Relationship = PhysicalSlotService.relationship(package)
		return agent != null and agent.phase == C_CustomerAgent.Phase.INSPECTING and CustomerInspectionService.owner_for(package) == actor and stored != null and (stored.relation as R_StoredIn).applied
	if CustomerInspectionService.owner_for(package) != null:
		return false
	if InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.DRAWING:
		return false

	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var ray: RayCast3D = actor.get("interaction_ray_cast") as RayCast3D
	if interactor == null or not is_instance_valid(ray):
		return false

	var body: Node3D = package as Node as Node3D
	if body == null:
		return false

	for grip: Relationship in package.relationships:
		if grip.relation is R_HeldBy and grip.target == actor:
			var held_distance: float = ray.global_position.distance_to(body.global_position)
			return held_distance <= interactor.interaction_distance

	if interactor.target != package:
		return false

	ray.force_raycast_update()
	if not ray.is_colliding():
		return false

	var collider: Node = ray.get_collider() as Node
	while collider != null and not collider is Entity:
		collider = collider.get_parent()
	if collider != package:
		return false

	var hit_distance: float = ray.global_position.distance_to(ray.get_collision_point())
	return hit_distance <= interactor.interaction_distance


## Повторно проверяет доступ перед отправкой; наблюдатель проверяет ещё раз перед фиксацией.
static func request_open(actor: Entity, package: Entity) -> bool:
	if not can_open(actor, package):
		return false

	var request: PackageOpenRequest = PackageOpenRequest.new()
	request.actor = actor
	request.package = package
	ECS.world.emit_event(PackageOpenRequest.EVENT, package, request)
	return true

#endregion
