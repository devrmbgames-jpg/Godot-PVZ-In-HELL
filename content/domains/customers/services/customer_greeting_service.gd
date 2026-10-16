extends RefCounted
## Выполняет авторское знакомство, используя существующие визит, диалог и взаимодействия.
class_name CustomerGreetingService


#region Знакомство
## Сообщает номер однократно при быстром знакомстве либо обнаруженном заднем контакте.
static func announce_order(customer: E_NpcCharacter, visit: CustomerVisit) -> void:
	if visit == null or visit.finished:
		return

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if (
		agent == null or agent.order_announced or agent.rear_contact_pending
		or agent.phase
		not in [
			C_CustomerAgent.Phase.APPROACHING,
			C_CustomerAgent.Phase.WAITING,
			C_CustomerAgent.Phase.WAITING_FOR_PACKAGE,
		]
	):
		return
	# A detected rear contact announces its order even for an ordinary manual visit.
	# rear_contact_pending above keeps the hidden arrival silent until actual observation.
	if (
		not CustomerPresentation.uses_quick_visit(visit)
		and not (
			agent.service_contact_position.is_finite()
			and CustomerPresentation.uses_rear_announcement(visit)
		)
	):
		return
	if CustomerPresentation.registered_number(visit) < 0:
		return

	agent.order_announced = true
	var message: String = CustomerPresentation.request_text(visit)
	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	if (
		challenge != null and challenge.definition != null
		and challenge.phase == C_Challenge.Phase.ACTIVE
	):
		message += "\n" + challenge.definition.rule_text
	customer.show_message(message)

#endregion
