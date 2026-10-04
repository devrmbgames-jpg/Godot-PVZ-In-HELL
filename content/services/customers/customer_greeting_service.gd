extends RefCounted
## Выполняет авторское знакомство, используя существующие визит, диалог и взаимодействия.
class_name CustomerGreetingService

const FALLBACK_EYE_HEIGHT: float = 1.3
const DEFAULT_OCCLUSION_MASK: int = 31


#region Знакомство
## Сообщает зарегистрированный номер однократно для быстрого знакомства.
static func announce_order(customer: E_Customer, visit: CustomerVisit) -> void:
	if visit == null or visit.finished or not CustomerPresentation.uses_quick_visit(visit):
		return

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or agent.order_announced or agent.phase not in [C_CustomerAgent.Phase.APPROACHING, C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE]:
		return
	if CustomerPresentation.registered_number(visit) < 0:
		return

	agent.order_announced = true
	var message: String = CustomerPresentation.request_text(visit)
	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	if challenge != null and challenge.definition != null and challenge.phase == C_Challenge.Phase.ACTIVE:
		message += "\n" + challenge.definition.rule_text
	customer.show_message(message)


## Проверяет авторский автодиалог: дистанцию, видимость, готовность визита и свободный ввод.
static func tick(customer: E_Customer, visit: CustomerVisit) -> void:
	announce_order(customer, visit)
	if visit == null or visit.finished or visit.definition == null or visit.definition.introduction != DEF_Customer.Introduction.FIRST_APPROACH_DIALOGUE:
		return

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or agent.dialogue_started or agent.phase not in [C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE]:
		return

	var actor: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if not CustomerDialogueService.can_start(actor, customer):
		return

	var player_body: Node3D = actor as Node as Node3D
	var customer_body: Node3D = customer as Node as Node3D
	if player_body == null or player_body.global_position.distance_squared_to(customer_body.global_position) > pow(visit.definition.auto_dialogue_distance, 2.0):
		return
	if _has_line_of_sight(actor, customer):
		CustomerDialogueService.start(actor, customer)


#endregion

#region Физическая видимость
static func _has_line_of_sight(actor: Entity, customer: E_Customer) -> bool:
	var player: E_PhysicalCharacter = actor as E_PhysicalCharacter
	var player_body: Node3D = actor as Node as Node3D
	var customer_body: Node3D = customer as Node as Node3D
	var start: Vector3 = player.head_axis_x.global_position if player != null and is_instance_valid(player.head_axis_x) else player_body.global_position + Vector3.UP * FALLBACK_EYE_HEIGHT
	var end: Vector3 = customer.head_axis_x.global_position if is_instance_valid(customer.head_axis_x) else customer_body.global_position + Vector3.UP * FALLBACK_EYE_HEIGHT
	var excluded: Array[RID] = []
	for entity: Entity in [actor, customer]:
		var collider: CollisionObject3D = entity as Node as CollisionObject3D
		if collider != null:
			excluded.append(collider.get_rid())

	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end, DEFAULT_OCCLUSION_MASK, excluded)
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	if interactor != null:
		ray.collision_mask = interactor.collision_mask
	ray.hit_from_inside = true
	return customer_body.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

#endregion
