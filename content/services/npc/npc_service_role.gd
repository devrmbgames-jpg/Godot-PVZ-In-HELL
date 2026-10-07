extends RefCounted
## Обслуживание — временная роль постоянной личности с исключительным резервированием стойки.
class_name NpcServiceRole

const QUEUE_SPACING: float = 1.3

#region Планирование обслуживания
## Подготавливает до двух следующих получателей рядом с текущим; утро допускает прогулку.
static func enqueue_next(flow: C_CustomerFlow, cycle: C_DayCycle) -> bool:
	if cycle.phase not in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY]:
		return false
	var district: C_District = DistrictPopulationService.current()
	if _ready_queue().size() >= district.definition.prepared_customer_count + 1:
		return false

	for visit: CustomerVisit in flow.visits:
		if visit.started or not CustomerFlowService.visit_due(visit, cycle.day_index) or not CustomerFlowService.arrival_allowed(visit):
			continue
		var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
		var body: E_DistrictNpc = DistrictPopulationService.body_for(visit.customer_id)
		if person == null or person.death_day != 0 or body == null:
			defer_visit(body, visit, "Получатель недоступен")
			continue
		if body.has_component(C_CustomerAgent):
			continue
		var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
		if CombatService.target_for(body) != null or (awareness != null and (awareness.fleeing or awareness.hazard_distress)):
			defer_visit(body, visit, "Получатель покинул очередь из-за опасности")
			continue
		begin(body, person, visit, cycle.day_index)
		return true
	return false

## Добавляет визит сохранённому телу; движением управляет дерево решений.
static func begin(body: E_DistrictNpc, person: NpcRecord, visit: CustomerVisit, day_index: int) -> void:
	if person.placement != NpcRecord.Placement.STREET:
		body.place_at(DistrictPopulationService.position_for(person.home_id if person.placement == NpcRecord.Placement.HOME else person.portal_id))
		DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	var service: C_CustomerAgent = C_CustomerAgent.new()
	service.visit_id = visit.visit_id
	service.phase = C_CustomerAgent.Phase.QUEUED
	body.add_component(service)
	var motion: C_Motion = body.get_component(C_Motion) as C_Motion
	if motion != null:
		service.original_walk_speed = motion.max_speed
		motion.max_speed = maxf(motion.max_speed, DistrictPopulationService.current().definition.service_approach_speed)
	var station: E_DeliveryCounter = CustomerFlowService.counter()
	if station != null:
		var waiting: R_NpcWaitingAt = R_NpcWaitingAt.new()
		waiting.visit_id = visit.visit_id
		body.add_relationship(Relationship.new(waiting, station))

	var challenge: C_Challenge = body.get_component(C_Challenge) as C_Challenge
	if challenge != null:
		challenge.definition = null
	var district: C_District = DistrictPopulationService.current()
	visit.queue_order = district.next_service_order
	district.next_service_order += 1
	visit.started = true
	visit.visit_count += 1
	visit.last_visit_day = day_index
	CustomerFlowService.bind_parcel(body, visit)
	body.show_message(person.display_name + " · за посылкой")

## Возвращает живых получателей стойки из малого постоянного населения, включая свежие роли.
static func _prepared() -> Array[E_DistrictNpc]:
	var prepared: Array[E_DistrictNpc] = []
	var district: C_District = DistrictPopulationService.current()
	for person: NpcRecord in district.people:
		var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
		if body != null and body.enabled and not body.has_component(C_Death) and body.has_component(C_CustomerAgent) and NpcHomeDeliveryService.meeting_for(body) == null:
			prepared.append(body)
	prepared.sort_custom(func(first: E_DistrictNpc, second: E_DistrictNpc) -> bool:
		var first_visit: CustomerVisit = visit_for(first)
		var second_visit: CustomerVisit = visit_for(second)
		return first_visit != null and (second_visit == null or first_visit.queue_order < second_visit.queue_order)
	)
	return prepared

static func _ready_queue() -> Array[E_DistrictNpc]:
	var ready: Array[E_DistrictNpc] = []
	for body: E_DistrictNpc in _prepared():
		var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent.phase != C_CustomerAgent.Phase.WAITING_FOR_DARKNESS:
			ready.append(body)
	return ready

## Читает конкретный заказ текущей роли; живого назначения не создаёт.
static func visit_for(body: Entity) -> CustomerVisit:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	return CustomerFlowService.find_visit(agent.visit_id) if agent != null else null

## Проверяет, первый ли это ожидающий и свободна ли стойка в дневную фазу.
static func can_approach(body: E_DistrictNpc) -> bool:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null or cycle.phase != C_DayCycle.Phase.DAY:
		return false
	var station: E_DeliveryCounter = CustomerFlowService.counter()
	if station == null:
		return false
	var prepared: Array[E_DistrictNpc] = _prepared()
	var first_ready: E_DistrictNpc = null
	for candidate: E_DistrictNpc in prepared:
		var service: C_CustomerAgent = candidate.get_component(C_CustomerAgent) as C_CustomerAgent
		if service.phase == C_CustomerAgent.Phase.WAITING_FOR_DARKNESS and needs_darkness(candidate):
			continue
		first_ready = candidate
		break
	if first_ready != body:
		return false
	for participant: E_DistrictNpc in prepared:
		for link: Relationship in participant.relationships:
			if link.relation is R_NpcServiceAt:
				return false
	var flow: C_CustomerFlow = CustomerFlowService.current()
	return flow == null or flow.arrival_cooldown_seconds <= 0.0

## Резервирует стойку и начинает подход либо явное ожидание темноты у входа.
static func claim_counter(body: E_DistrictNpc) -> void:
	var visit: CustomerVisit = visit_for(body)
	var station: E_DeliveryCounter = CustomerFlowService.counter()
	if visit == null or station == null or not can_approach(body):
		return
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_DARKNESS if needs_darkness(body) else C_CustomerAgent.Phase.APPROACHING
	if agent.phase == C_CustomerAgent.Phase.APPROACHING:
		var reservation: R_NpcServiceAt = R_NpcServiceAt.new()
		reservation.visit_id = visit.visit_id
		body.add_relationship(Relationship.new(reservation, station))
	agent.elapsed = 0.0
	var destination: Vector3 = station.entry_position() if agent.phase == C_CustomerAgent.Phase.WAITING_FOR_DARKNESS else station.waiting_position()
	NpcIntentArbiter.move_to(body, destination, visit.definition.arrival_distance, C_NpcDecision.Owner.SERVICE)

## Выбирает следующую явную точку прогулки, а не строит маршрут перебором.
static func waiting_destination(body: E_DistrictNpc) -> Vector3:
	var station: E_DeliveryCounter = CustomerFlowService.counter()
	if station == null:
		return body.global_position
	var prepared: Array[E_DistrictNpc] = _ready_queue()
	var index: int = prepared.find(body)
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	var route_index: int = index - 1
	for link: Relationship in body.relationships:
		if link.relation is R_NpcWaitingAt:
			(link.relation as R_NpcWaitingAt).route_index = route_index
	if route_index < 0:
		return station.entry_position()
	var district: C_District = DistrictPopulationService.current()
	if not is_instance_valid(district.service_routes):
		district.service_routes = ECS.world.get_parent().get_node_or_null(district.definition.service_routes_path) as NpcServiceRoutes
	if district.service_routes == null:
		return station.entry_position()
	var marker: Node3D = district.service_routes.point_for(route_index, agent.waiting_point)
	if marker == null:
		return station.entry_position()
	var offset: Vector3 = marker.global_position - body.global_position
	offset.y = 0.0
	if offset.length_squared() <= QUEUE_SPACING * QUEUE_SPACING:
		agent.waiting_point += 1
		marker = district.service_routes.point_for(route_index, agent.waiting_point)
	return marker.global_position if marker != null else station.entry_position()

## Читает логическое освещение стойки без кратких тёмных кадров собственного мерцания.
static func needs_darkness(body: E_DistrictNpc) -> bool:
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id)
	var rule: DEF_NpcTrait = person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION)
	var station: E_DeliveryCounter = CustomerFlowService.counter()
	return rule != null and station != null and NpcLightingService.exposure_at(station.waiting_position() + Vector3.UP, [], null, true) > rule.light_threshold

## Предупреждает и запускает конечное мерцание только один раз за этот физический приход.
static func warn_light(body: E_DistrictNpc) -> void:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent.light_warning_started:
		return
	agent.light_warning_started = true
	var config: DEF_District = DistrictPopulationService.current().definition
	body.show_message("Я боюсь света. Выключите освещение ПВЗ, я подожду снаружи.")
	LightCircuitService.flicker(config.service_light_circuit, config.service_flicker_seconds, LightFlickerRequest.DEFAULT_INTERVAL_SECONDS, StringName("npc-light/" + String(agent.visit_id)))

## Учитывает часы роли один раз на обновление восприятия, без выбора поведения.
static func advance(body: E_DistrictNpc, delta: float) -> void:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return
	agent.elapsed += delta
	var station: E_DeliveryCounter = CustomerFlowService.counter()
	if station != null and agent.phase in [C_CustomerAgent.Phase.QUEUED, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS, C_CustomerAgent.Phase.APPROACHING]:
		var offset: Vector3 = body.global_position - station.entry_position()
		offset.y = 0.0
		if offset.length_squared() <= QUEUE_SPACING * QUEUE_SPACING:
			agent.entrance_wait_elapsed += delta

## Переносит недоступный приход на следующее утро без автоматической потери или оплаты.
static func defer_visit(body: E_DistrictNpc, visit: CustomerVisit, reason: String) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null or visit.deferred_day == cycle.day_index:
		return
	visit.deferred_day = cycle.day_index
	visit.defer_reason = reason
	visit.next_followup_day = cycle.day_index + 1
	visit.followup_committed = true
	visit.finished = true
	visit.finished_day = cycle.day_index
	visit.started = false
	if is_instance_valid(body):
		CustomerInspectionService.end(body)
		NpcHomeDeliveryService.release_meeting(body)
		release(body, visit.visit_id)
		var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
		var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id)
		if person != null:
			person.planned_phase = -1
		body.show_message(reason + ". Приду в другой день.")

## Разрешает вход после выключения света; движение выполняет отдельный лист дерева.
static func enter_counter(body: E_DistrictNpc) -> void:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	claim_counter(body)
	var config: DEF_District = DistrictPopulationService.current().definition
	LightCircuitService.stop_flicker(config.service_light_circuit, StringName("npc-light/" + String(agent.visit_id)))

## Фиксирует прибытие к стойке либо к двери без смены экономического исхода.
static func arrive(body: E_DistrictNpc) -> void:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	_restore_walk_speed(body, agent)
	agent.phase = C_CustomerAgent.Phase.WAITING if NpcHomeDeliveryService.meeting_for(body) == null else C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	agent.elapsed = 0.0
	NpcIntentService.stop(body)
	body.show_message("Здравствуйте!" if agent.phase == C_CustomerAgent.Phase.WAITING else CustomerPresentation.request_text(visit_for(body)))

#endregion

#region Завершение роли
## Прерывает нерешённый визит, освобождая коробку и стойку без выдуманного результата.
static func suspend(body: E_DistrictNpc) -> void:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return

	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	var home: NpcHomeDelivery = NpcHomeDeliveryService.meeting_for(body)
	if visit == null:
		release(body, agent.visit_id)
		return
	if visit.actual in [CustomerVisit.Actual.DELIVERED, CustomerVisit.Actual.CUSTOMER_REFUSED]:
		if home != null:
			NpcHomeDeliveryService.complete(home)
		else:
			finish_appearance(body, visit)
		return

	CustomerInspectionService.end(body)
	NpcHomeDeliveryService.release_meeting(body)
	release(body, visit.visit_id)
	if home == null:
		var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
		var reason: String = decision.active_behavior if decision != null else "опасность"
		defer_visit(body, visit, "Приход прерван: " + reason)
	else:
		visit.started = false
		visit.finished = true

## Завершает только визит, сохраняя личность и правила нерешённого заказа.
static func finish_appearance(body: E_DistrictNpc, visit: CustomerVisit) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	var day_index: int = cycle.day_index if cycle != null else visit.last_visit_day
	CustomerInspectionService.end(body)
	ChallengeService.cancel(body)
	if not visit.finished:
		CustomerFlowService.finish(visit, day_index)
	release(body, visit.visit_id)

	var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
	if person != null and person.death_day == 0:
		person.planned_phase = -1
		body.present_profile(person.profile)
		body.show_message(person.display_name)

## Снимает роль и только её живые связи с коробкой и стойкой.
static func release(body: Entity, visit_id: StringName) -> void:
	_restore_walk_speed(body, body.get_component(C_CustomerAgent) as C_CustomerAgent)
	var district: C_District = DistrictPopulationService.current()
	if district != null:
		LightCircuitService.stop_flicker(district.definition.service_light_circuit, StringName("npc-light/" + String(visit_id)))
	NpcDialogueService.end(body)
	var parcel: Entity = CustomerFlowService.parcel_for(CustomerFlowService.find_visit(visit_id).package_id) if CustomerFlowService.find_visit(visit_id) != null else null
	if parcel != null:
		for link: Relationship in parcel.relationships.duplicate():
			if link.relation is R_AssignedTo and (link.relation as R_AssignedTo).visit_id == visit_id:
				parcel.remove_relationship(link)
	for link: Relationship in body.relationships.duplicate():
		if link.relation is R_NpcServiceAt or link.relation is R_NpcWaitingAt:
			body.remove_relationship(link)
	if body.has_component(C_CustomerAgent):
		body.remove_component(C_CustomerAgent)

static func _restore_walk_speed(body: Entity, agent: C_CustomerAgent) -> void:
	var motion: C_Motion = body.get_component(C_Motion) as C_Motion
	if agent != null and motion != null and agent.original_walk_speed >= 0.0:
		motion.max_speed = agent.original_walk_speed
		agent.original_walk_speed = -1.0

## Применяет окончательную смерть ко всем заказам без переназначения владельца.
static func mark_dead(person: NpcRecord, body: E_DistrictNpc, day_index: int) -> void:
	var flow: C_CustomerFlow = CustomerFlowService.current()
	if flow == null:
		return

	var death: C_Death = body.get_component(C_Death) as C_Death
	var defeated_by_player: bool = false
	if death != null and death.cause != null and death.cause.request != null:
		var actor: Entity = death.cause.request.instigator
		if not is_instance_valid(actor):
			actor = death.cause.request.source
		defeated_by_player = is_instance_valid(actor) and actor.has_component(C_PlayerInputController)
	for visit: CustomerVisit in flow.visits:
		if visit.customer_id != person.npc_id:
			continue

		visit.customer_dead = true
		visit.defeated_by_player = defeated_by_player
		if not visit.finished:
			CustomerFlowService.finish(visit, day_index)
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent != null:
		CustomerInspectionService.end(body)
		release(body, agent.visit_id)

## Преобразует эскалацию обслуживания в обычный выбор боевой цели.
static func escalate(body: E_DistrictNpc) -> void:
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if player != null:
		var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
		var incident: StringName = StringName("service/%s/offense" % agent.visit_id)
		body.show_message("Вы нарушили условия выдачи. Объяснитесь.")
		NpcSocialService.react(body, player, NpcMemory.Kind.OFFENSE, incident)
#endregion
