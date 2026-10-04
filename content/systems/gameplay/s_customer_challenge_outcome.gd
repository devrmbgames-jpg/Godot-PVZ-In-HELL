extends System
## Применяет результат к удовлетворённости клиента без управления движением и вычисления условий.
class_name S_CustomerChallengeOutcome

## Принятый клиентский результат просит боевой адаптер эскалировать конфликт.
signal escalation_requested(customer: Entity, actor: Entity, event: ChallengeResolution)


## Применяет последствия после общего разрешения испытания.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_ChallengeRuntime]}


## Выбирает испытания текущих клиентов.
func query() -> QueryBuilder:
	return q.with_all([C_Challenge, C_CustomerAgent]).iterate([C_Challenge, C_CustomerAgent])


## Однократно передаёт итог в результат обслуживания и публикует принятую эскалацию.
func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var states: Array = components[0]
	var agents: Array = components[1]
	for index: int in entities.size():
		var state: C_Challenge = states[index] as C_Challenge
		if state.pending_result == null or state.consequences_applied:
			continue

		var agent: C_CustomerAgent = agents[index] as C_CustomerAgent
		var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
		if visit == null or visit.finished:
			continue

		var applied: bool = CustomerOutcomeService.apply_challenge_result(visit, state.pending_result)
		state.consequences_applied = true
		if applied:
			CustomerArrivalService.apply_result(entities[index], state.pending_result)
		if applied and state.pending_result.request_escalation:
			state.escalation_request = state.pending_result
			escalation_requested.emit(entities[index], ChallengeService.actor_for(entities[index]), state.pending_result)
