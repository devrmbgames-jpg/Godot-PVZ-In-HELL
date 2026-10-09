extends RefCounted
## Открывает разговор: DialogueManager выбирает текст и ветки, сервисы изменяют игровые данные.
class_name CustomerDialogueService

const DIALOGUE_PATH: String = "res://content/domains/customers/dialogue/customer_service.dialogue"
const ACTIVE_GROUP: StringName = &"customer_dialogue_panel"


#region Запуск разговора
## Проверяет живого получателя, готовую фазу визита и отсутствие конкурирующего модального ввода.
static func can_start(actor: Entity, customer: E_NpcCharacter) -> bool:
	if not GrabQueries.holder_available(actor) or not EntityAvailability.contains(customer, ECS.world) or customer.has_component(C_Death):
		return false
	if InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.PUSH or bool(Console.is_visible()):
		return false

	var visit: CustomerVisit = null
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent != null:
		visit = CustomerFlowQueries.find_visit(agent.visit_id)
	if visit == null or visit.finished or (not customer.has_component(C_NpcIdentity) and CustomerPresentation.uses_quick_order(visit.definition)):
		return false
	return agent.phase in [C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE] and customer.get_tree().get_nodes_in_group(ACTIVE_GROUP).is_empty()


## Запрашивает native UI через явную синхронную границу после gameplay eligibility.
static func request_open(actor: Entity, customer: E_NpcCharacter) -> bool:
	if not can_start(actor, customer):
		return false
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var request: CustomerDialogueOpenRequest = CustomerDialogueOpenRequest.new(actor, agent)
	ECS.world.emit_event(CustomerDialogueOpenRequest.EVENT, customer, request)
	return request.opened


## Отмечает успешное открытие только для captured role после UI callback boundary.
static func mark_opened(customer: E_NpcCharacter, captured_agent: C_CustomerAgent) -> bool:
	if customer.get_component(C_CustomerAgent) != captured_agent:
		return false
	captured_agent.dialogue_started = true
	return true

#endregion

#region Игровой lifecycle разговора
## Переводит тот же действующий визит в диалог и запрашивает живую связь у NPC owner.
static func begin(actor: Entity, customer: E_NpcCharacter, visit_id: StringName) -> bool:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(visit_id)
	if agent == null or agent.visit_id != visit_id or visit == null or visit.finished or customer.has_component(C_Death):
		return false
	if NpcDialogueService.participant(customer) != null:
		return false
	if not CustomerFlowService.enter_service_phase(customer, C_CustomerAgent.Phase.DIALOGUE):
		return false

	return NpcDialogueService.begin(actor, customer)


## Завершает разговор зарегистрированного тела; actor может отсутствовать после закрытия UI/lifetime boundary.
static func end(actor: Entity, customer: E_NpcCharacter, visit_id: StringName) -> void:
	if NpcDialogueService.participant(customer) == actor or not EntityAvailability.contains(actor, ECS.world):
		NpcDialogueService.end(customer)

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(visit_id)
	if agent == null or agent.visit_id != visit_id or visit == null or visit.finished or customer.has_component(C_Death):
		return
	if agent.phase != C_CustomerAgent.Phase.DIALOGUE:
		return

	# UI releases modal control before requesting gameplay resumption.
	CustomerFlowService.enter_service_phase(customer, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	ChallengeService.activate(customer)
#endregion
