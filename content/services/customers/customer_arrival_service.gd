extends RefCounted
## Управляет ожиданием темноты при старом испытании; свет и движение принадлежат своим сервисам.
class_name CustomerArrivalService


#region Ожидание и результат
## При включённом свете ставит клиента ждать темноты и запускает авторское мерцание.
static func begin(customer: E_Customer, challenge: C_Challenge) -> void:
	var rule: DEF_LightChallengeCondition = _darkness_rule(challenge)
	if rule == null or not LightCircuitService.is_enabled(rule.circuit_id):
		return

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_DARKNESS
	agent.elapsed = 0.0
	NpcIntentService.stop(customer)
	LightCircuitService.flicker(rule.circuit_id, challenge.definition.timeout_seconds, rule.flicker_interval_seconds, StringName(customer.id))


## Возвращает true, когда CustomerFlow должен отправить ожидающего клиента обратно.
static func tick(customer: E_Customer, agent: C_CustomerAgent, visit: CustomerVisit, cycle: C_DayCycle) -> bool:
	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	var rule: DEF_LightChallengeCondition = _darkness_rule(challenge)
	if rule == null or cycle.phase != C_DayCycle.Phase.DAY or challenge.result == ChallengeResult.Type.CANCELLED:
		return true
	if not LightCircuitService.is_enabled(rule.circuit_id) and challenge.result != ChallengeResult.Type.FAILURE:
		agent.phase = C_CustomerAgent.Phase.APPROACHING
		agent.elapsed = 0.0
		var station: E_DeliveryCounter = CustomerFlowService.counter()
		if station == null:
			return true

		NpcIntentService.move_to(customer, station.waiting_position(), visit.definition.arrival_distance)
		NpcIntentService.look_along_movement(customer)
		customer.show_message("Теперь я могу войти. Спасибо.")
	return false


## После провала соответствующего старого испытания выключает его световую цепь.
static func apply_result(customer: Entity, event: ChallengeResolution) -> void:
	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	var rule: DEF_LightChallengeCondition = _darkness_rule(challenge)
	if rule != null and event.result == ChallengeResult.Type.FAILURE:
		LightCircuitService.set_by_id(rule.circuit_id, false)


#endregion

#region Чтение авторского условия
static func _darkness_rule(challenge: C_Challenge) -> DEF_LightChallengeCondition:
	if challenge == null or challenge.definition == null or challenge.definition.trigger != DEF_Challenge.Trigger.ON_ARRIVAL:
		return null

	var rule: DEF_LightChallengeCondition = challenge.definition.condition as DEF_LightChallengeCondition
	return rule if rule != null and not rule.required_enabled and rule.wait_outside_until_dark else null

#endregion
