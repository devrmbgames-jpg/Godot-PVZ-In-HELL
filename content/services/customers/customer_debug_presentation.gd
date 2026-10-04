extends RefCounted
## Читает состояние обслуживания для отладки; визиты и таймеры принадлежат игровым сервисам.
class_name CustomerDebugPresentation

const HEALTH_SEGMENTS: int = 10
const MINIMUM_HEALTH_MAXIMUM: float = 0.001
const PHASE_NAMES: Array[String] = ["Подходит", "Приветствие", "Диалог", "Ждёт посылку", "Получил заказ", "Осматривает", "Уходит", "Агрессивен", "Закончил", "Ждёт темноты", "Идёт в кабинку", "Осмотр в кабинке", "Возвращается к выдаче", "В очереди"]


static func summary() -> String:
	if not is_instance_valid(ECS.world):
		return ""

	var count: int = ECS.world.query.with_all([C_CustomerAgent]).execute().size()
	var flow: C_CustomerFlow = CustomerFlowService.current()
	var interval: float = flow.arrival_cooldown_seconds if flow != null else 0.0
	var result: String = "Клиенты: %d · Пауза до следующего: %.0f с\nТаймеры, условия и задачи — над NPC" % [count, ceilf(interval)]
	var shift: String = DayPhaseService.shift_status(DayPhaseService.current())
	return result + ("\n" + shift if not shift.is_empty() else "")


static func text_for(customer: E_Customer) -> String:
	if not DebugHudService.is_enabled() or not EntityAvailability.contains(customer, ECS.world):
		return ""

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id) if agent != null else null
	if visit == null or visit.definition == null:
		return ""

	var number: int = CustomerPresentation.registered_number(visit)
	var lines: Array[String] = ["%s · %s" % [CustomerPresentation.customer_name(visit), "№%03d" % number if number >= 0 else "без номера"]]
	var duration: float = _phase_duration(agent, visit.definition)
	lines.append("%s · %.1f / %.1f с" % [PHASE_NAMES[agent.phase], agent.elapsed, duration])
	if agent.phase in [C_CustomerAgent.Phase.GOING_TO_BOOTH, C_CustomerAgent.Phase.INSPECTING, C_CustomerAgent.Phase.RETURNING_FROM_BOOTH]:
		lines.append("Распаковка %.0f%% · забрать %.0f%% · решение после возврата" % [visit.definition.inspection_unpack_probability * 100.0, visit.definition.inspection_keep_probability * 100.0])
	if CustomerPresentation.uses_quick_order(visit.definition):
		lines.append("Без диалога · номер %s" % ["сообщён" if agent.order_announced else "ждёт регистрации"])
	elif visit.definition.introduction == DEF_Customer.Introduction.FIRST_APPROACH_DIALOGUE and not agent.dialogue_started and agent.phase in [C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE]:
		lines.append("Автодиалог: ≤%.1f м · видимость · свободный ввод" % visit.definition.auto_dialogue_distance)

	var health: C_Health = customer.get_component(C_Health) as C_Health
	if health != null:
		var fraction: float = clampf(health.get_hp_current() / maxf(health.get_hp_max(), MINIMUM_HEALTH_MAXIMUM), 0.0, 1.0)
		var segments: int = roundi(fraction * HEALTH_SEGMENTS)
		lines.append("HP [%s%s] %.0f/%.0f · довольство %d" % ["■".repeat(segments), "□".repeat(HEALTH_SEGMENTS - segments), health.get_hp_current(), health.get_hp_max(), visit.satisfaction])
	var challenge: C_Challenge = customer.get_component(C_Challenge) as C_Challenge
	if challenge != null and challenge.definition != null and challenge.phase not in [C_Challenge.Phase.INACTIVE, C_Challenge.Phase.CLEANUP]:
		lines.append("Задача: %s · %s" % [challenge.definition.key, C_Challenge.Phase.keys()[challenge.phase]])
		if challenge.definition.timeout_seconds > 0.0:
			lines.append("Осталось %.1f с" % maxf(0.0, challenge.definition.timeout_seconds - challenge.elapsed))
		else:
			lines.append("До физического ухода · %.1f с" % challenge.elapsed)
		var light: DEF_LightChallengeCondition = challenge.definition.condition as DEF_LightChallengeCondition
		if light != null:
			lines.append("Свет: нужен %s · сейчас %s" % ["включён" if light.required_enabled else "выключен", "включён" if LightCircuitService.is_enabled(light.circuit_id) else "выключен"])
		var gaze: C_GazeChallenge = customer.get_component(C_GazeChallenge) as C_GazeChallenge
		if challenge.definition.condition is DEF_GazeChallengeCondition and gaze != null:
			lines.append("Взгляд %.1f/%.1f с · LOS: %s" % [challenge.violation_elapsed, challenge.definition.violation_grace_seconds, "есть" if gaze.line_of_sight else "нет"])
		if challenge.definition.condition is DEF_FloorChallengeCondition:
			lines.append("Опасный пол %.1f/%.1f с" % [challenge.violation_elapsed, challenge.definition.violation_grace_seconds])
			var floor: C_FloorChallenge = customer.get_component(C_FloorChallenge) as C_FloorChallenge
			for relation: Relationship in customer.relationships:
				if relation.relation is R_ChallengeEffect and EntityAvailability.contains(relation.target, ECS.world):
					var effect: Entity = relation.target as Entity
					var timer: C_FloorHazard = effect.get_component(C_FloorHazard) as C_FloorHazard
					if timer != null:
						lines.append("Пол: %s · Таймер урона %.2f с" % ["опасный контакт" if floor != null and floor.touching_danger else "безопасно", timer.damage_elapsed])
	return "\n".join(lines)


static func _phase_duration(agent: C_CustomerAgent, definition: DEF_Customer) -> float:
	match agent.phase:
		C_CustomerAgent.Phase.APPROACHING: return definition.approach_timeout
		C_CustomerAgent.Phase.WAITING: return definition.greeting_seconds
		C_CustomerAgent.Phase.WAITING_FOR_PACKAGE, C_CustomerAgent.Phase.DIALOGUE, C_CustomerAgent.Phase.OPTIONAL_FITTING: return definition.patience_seconds
		C_CustomerAgent.Phase.RECEIVING: return definition.receiving_seconds
		C_CustomerAgent.Phase.INSPECTING: return definition.inspection_seconds
		C_CustomerAgent.Phase.GOING_TO_BOOTH, C_CustomerAgent.Phase.RETURNING_FROM_BOOTH: return definition.approach_timeout
		C_CustomerAgent.Phase.LEAVING: return maxf(DEF_Customer.MINIMUM_LEAVING_SECONDS, definition.leaving_seconds)
		C_CustomerAgent.Phase.AGGRESSIVE: return definition.aggressive_seconds
		C_CustomerAgent.Phase.WAITING_FOR_DARKNESS: return definition.challenge.timeout_seconds if definition.challenge != null else 0.0
	return 0.0
