extends RefCounted
## Управляет ожиданием темноты при старом испытании; свет и движение принадлежат своим сервисам.
class_name CustomerArrivalService


#region Ожидание и результат
## При включённом свете ставит клиента ждать темноты и запускает авторское мерцание.
static func begin(customer: E_NpcCharacter, challenge: C_Challenge) -> void:
	var rule: DEF_LightChallengeCondition = darkness_rule(challenge)
	if rule == null or not LightCircuitService.is_enabled(rule.circuit_id):
		return

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_DARKNESS
	agent.elapsed = 0.0
	NpcIntentService.stop(customer)
	LightCircuitService.flicker(rule.circuit_id, challenge.definition.timeout_seconds, rule.flicker_interval_seconds, StringName(customer.id))


## После провала соответствующего старого испытания выключает его световую цепь.
static func apply_result(customer: Entity, event: ChallengeResolution) -> void:
	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	var rule: DEF_LightChallengeCondition = darkness_rule(challenge)
	if rule != null and event.result == ChallengeResult.Type.FAILURE:
		LightCircuitService.set_by_id(rule.circuit_id, false)


#endregion

#region Чтение авторского условия
## Reads the optional authored darkness gate without advancing its lifecycle.
static func darkness_rule(challenge: C_Challenge) -> DEF_LightChallengeCondition:
	if challenge == null or challenge.definition == null or challenge.definition.trigger != DEF_Challenge.Trigger.ON_ARRIVAL:
		return null

	var rule: DEF_LightChallengeCondition = challenge.definition.condition as DEF_LightChallengeCondition
	return rule if rule != null and not rule.required_enabled and rule.wait_outside_until_dark else null

#endregion
