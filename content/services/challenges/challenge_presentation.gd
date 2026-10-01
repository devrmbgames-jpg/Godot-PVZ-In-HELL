extends RefCounted
## Read-only rule/countdown/result presentation; never owns challenge state.
class_name ChallengePresentation


static func text_for(actor: Entity) -> String:
	if not EntityAvailability.contains(actor, ECS.world):
		return ""
	for subject: Entity in ECS.world.query.with_all([C_Challenge]).execute():
		if ChallengeService.actor_for(subject) != actor:
			continue
		var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
		if state.definition == null:
			continue
		match state.phase:
			C_Challenge.Phase.ACTIVE:
				if state.definition.completion in [DEF_Challenge.Completion.UNTIL_DEPARTURE, DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE]:
					var preparation: int = ceili(maxf(0.0, state.definition.preparation_seconds - state.elapsed))
					if preparation > 0:
						return "%s\nПодготовка: %d с • условие действует до ухода клиента" % [state.definition.rule_text, preparation]
					return "%s\nДо ухода клиента%s" % [state.definition.rule_text, " • нарушение учтено" if state.condition_violated else ""]
				if state.definition.timeout_seconds > 0.0:
					var remaining: int = ceili(maxf(0.0, state.definition.timeout_seconds - state.elapsed))
					return "%s\nОсталось: %d с" % [state.definition.rule_text, remaining]
				return state.definition.rule_text
			C_Challenge.Phase.SUCCESS:
				return "Условие выполнено. Клиент доволен."
			C_Challenge.Phase.FAILURE:
				return "Условие нарушено. Клиент недоволен."
	return ""


static func debug_text_for(actor: Entity) -> String:
	if not EntityAvailability.contains(actor, ECS.world):
		return ""
	var lines: PackedStringArray = ["ЗАДАЧИ / УСЛОВИЯ (DEBUG)"]
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle != null:
		lines.append("День %d • %s • клиентов: %d" % [cycle.day_index, String(C_DayCycle.Phase.keys()[cycle.phase]), cycle.remaining_customer_events])
	var found: bool = false
	for subject: Entity in ECS.world.query.with_all([C_Challenge]).execute():
		var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
		if state.definition == null:
			continue
		found = true
		lines.append("%s: %s" % [state.definition.key, String(C_Challenge.Phase.keys()[state.phase])])
		lines.append("Задача: " + state.definition.rule_text)
		var condition: DEF_LightChallengeCondition = state.definition.condition as DEF_LightChallengeCondition
		if condition != null:
			var circuit: C_LightCircuit = LightCircuitService.state_for(condition.circuit_id)
			var actual: String = "недоступен" if circuit == null else ("ВКЛ" if circuit.enabled else "ВЫКЛ")
			lines.append("Условие %s: нужно %s • сейчас %s" % [condition.circuit_id, "ВКЛ" if condition.required_enabled else "ВЫКЛ", actual])
		var gaze_rule: DEF_GazeChallengeCondition = state.definition.condition as DEF_GazeChallengeCondition
		var gaze: C_GazeChallenge = subject.get_component(C_GazeChallenge) as C_GazeChallenge
		if gaze_rule != null and gaze != null:
			lines.append("Взгляд: нужно %s • сейчас %s" % ["смотреть" if gaze_rule.required_attention else "отвести", "видит" if gaze.attention else "не видит"])
			lines.append("Угол %.1f / %.1f° • расстояние %.1f / %.1f м" % [gaze.angle_degrees, gaze_rule.half_angle_degrees, gaze.distance, gaze_rule.maximum_distance])
			lines.append("LOS: %s • данные: %s" % ["есть" if gaze.line_of_sight else "нет", "готовы" if gaze.sample_valid else "нет"])
		if state.definition.completion in [DEF_Challenge.Completion.UNTIL_DEPARTURE, DEF_Challenge.Completion.UNTIL_DEPARTURE_OR_FAILURE]:
			lines.append("До ухода • прошло %.1f с • подготовка %.1f с" % [state.elapsed, maxf(0.0, state.definition.preparation_seconds - state.elapsed)])
			lines.append("Нарушение %.1f / %.1f с • учтено: %s" % [state.violation_elapsed, state.definition.violation_grace_seconds, "да" if state.condition_violated else "нет"])
		else:
			lines.append("Таймер %.1f / %.1f с" % [state.elapsed, state.definition.timeout_seconds])
		var agent: C_CustomerAgent = subject.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent != null:
			var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
			lines.append("Клиент %s • таймер %.1f с" % [String(C_CustomerAgent.Phase.keys()[agent.phase]), agent.elapsed])
			if visit != null:
				lines.append("Satisfaction Δ: %d" % visit.challenge_satisfaction_delta)
		lines.append("Результат: %s • escalation: %s" % [ChallengeResult.key(state.result), "да" if state.escalation_request != null else "нет"])
	if not found:
		lines.append("Челлендж: ожидание клиента")
	return "\n".join(lines)
