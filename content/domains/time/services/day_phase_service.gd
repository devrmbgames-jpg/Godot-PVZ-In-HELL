extends RefCounted
## Чтение и запросы игрового цикла; переходы исполняет S_DayPhase.
class_name DayPhaseService


#region Состояние и доступность переходов
## Проверяет фазу, отсутствие ожидающего запроса и актуальные запреты смены/сна.
static func permits(cycle: C_DayCycle, kind: DayTransitionRequest.Kind) -> bool:
	if cycle == null or cycle.pending_transition != null:
		return false

	match kind:
		DayTransitionRequest.Kind.START_SHIFT:
			return cycle.phase == C_DayCycle.Phase.MORNING and start_blockers(cycle).is_empty()

		DayTransitionRequest.Kind.FINISH_SHIFT:
			return cycle.phase == C_DayCycle.Phase.DAY and finish_blockers(cycle).is_empty()

		DayTransitionRequest.Kind.SLEEP:
			return cycle.phase == C_DayCycle.Phase.EVENING and NpcSleepService.blockers().is_empty()
	return false


#endregion

#region Условия и представление
## Читает единый текущий запрет начала смены: поставка, разгрузка, ручной LOST и игрок в кузове.
static func start_blockers(cycle: C_DayCycle) -> PackedStringArray:
	return ReceivingShiftService.status(cycle).reasons


## Собирает одинаковые текущие запреты для запроса, фиксации перехода и интерфейса.
static func finish_blockers(cycle: C_DayCycle) -> PackedStringArray:
	var reasons: PackedStringArray = []
	if cycle == null:
		return ["Смена недоступна"]

	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	var unfinished: int = CustomerFlowQueries.actionable_remaining(flow, cycle.day_index) if flow != null else cycle.remaining_customer_events
	if cycle.require_finished_customers and unfinished > 0:
		reasons.append("Завершить визиты: %d" % unfinished)
	var shift_seconds: float = GameTimeQueries.shift_seconds(cycle)
	if cycle.minimum_shift_seconds > shift_seconds:
		var remaining_seconds: float = ceilf(cycle.minimum_shift_seconds - shift_seconds)
		reasons.append("До конца смены: %.0f с" % remaining_seconds)
	if cycle.require_empty_customer_room:
		var inside: int = customers_in_room(cycle)
		if inside < 0:
			reasons.append("Не настроена зона посетителей")
		elif inside > 0:
			reasons.append("Посетителей в здании: %d" % inside)
	if cycle.require_all_planned_arrivals and flow == null:
		reasons.append("Не настроен план посетителей")
	elif cycle.require_all_planned_arrivals:
		var unarrived: int = 0
		for visit: CustomerVisit in flow.visits:
			if CustomerFlowQueries.visit_due(visit, cycle.day_index) and not visit.started and CustomerFlowQueries.arrival_allowed(visit):
				unarrived += 1
		if unarrived > 0:
			reasons.append("Ожидаются запланированные клиенты: %d" % unarrived)
	return reasons


## Считает живых незавершённых клиентов; -1 означает неверную настройку зоны.
static func customers_in_room(cycle: C_DayCycle) -> int:
	if not is_instance_valid(ECS.world):
		return 0 if cycle.customer_room_path.is_empty() else -1

	var room: Area3D = null
	if not cycle.customer_room_path.is_empty():
		var owner: Entity = ECS.world.query.with_all([C_DayCycle]).execute_one()
		room = owner.get_node_or_null(cycle.customer_room_path) as Area3D if owner != null else null
		if room == null or not room.is_inside_tree() or not room.monitoring:
			return -1

	var count: int = 0
	for customer: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var body: Node3D = customer as Node as Node3D
		var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
		var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
		if visit != null and visit.finished:
			continue
		if not customer.has_component(C_Death) and (room == null or (body != null and room.overlaps_body(body))):
			count += 1
	return count


## Форматирует актуальные запреты завершения смены или сна для интерфейса.
static func shift_status(cycle: C_DayCycle) -> String:
	if cycle == null:
		return ""
	if cycle.phase == C_DayCycle.Phase.MORNING:
		var start_reasons: PackedStringArray = start_blockers(cycle)
		return "Начало смены доступно" if start_reasons.is_empty() else "Начало смены: " + " · ".join(start_reasons)
	if cycle.phase == C_DayCycle.Phase.EVENING:
		var sleep_reasons: PackedStringArray = NpcSleepService.blockers()
		return "Сон доступен" if sleep_reasons.is_empty() else "Сон: " + " · ".join(sleep_reasons)
	if cycle.phase != C_DayCycle.Phase.DAY:
		return ""

	var reasons: PackedStringArray = finish_blockers(cycle)
	var availability: String = "Завершение доступно" if reasons.is_empty() else " · ".join(reasons)
	return "Смена %.0f с · %s" % [floorf(GameTimeQueries.shift_seconds(cycle)), availability]


#endregion

#region Отправка запроса
## Сохраняет один допустимый запрос с совпадающими ожидаемыми днём и фазой.
static func submit(request: DayTransitionRequest) -> bool:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if request == null or not permits(cycle, request.kind):
		return false
	if request.expected_day != cycle.day_index or request.expected_phase != cycle.phase:
		return false

	cycle.pending_transition = request
	return true

#endregion
