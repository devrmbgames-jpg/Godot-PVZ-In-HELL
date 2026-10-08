extends RefCounted
## Добровольная доставка использует обычную проверку коробки и однократную отдельную доплату.
class_name NpcHomeDeliveryService

#region Обязательства
## Адаптирует постоянное личное предложение к существующему клиентскому диалогу.
static func offer_for(body: E_DistrictNpc) -> CustomerVisit:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if cycle == null or cycle.phase not in [C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		return null
	var active: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	var job: NpcHomeDelivery = HomeDeliveryQueries.personal_for(NpcSocialService.identity_for(body), active.visit_id if active != null else &"")
	return CustomerFlowQueries.find_visit(job.visit_id) if job != null else null

## После отказа получатель сам приходит через 1–3 дня; срок фиксирован для заказа.
static func decline(body: E_DistrictNpc) -> bool:
	var visit: CustomerVisit = offer_for(body)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if visit == null or cycle == null:
		return false

	var job: NpcHomeDelivery = HomeDeliveryQueries.personal_for(visit.customer_id, visit.visit_id)
	if job == null or not NpcDeliveryOfferService.decline(job.job_id):
		return false
	body.show_message("Тогда зайду сам через %d дн." % (visit.next_followup_day - cycle.day_index))
	return true

## Принимает уже выбранное личное предложение и завершает визит к стойке.
static func accept(body: E_DistrictNpc) -> bool:
	var visit: CustomerVisit = offer_for(body)
	if visit == null:
		return false

	var job: NpcHomeDelivery = HomeDeliveryQueries.personal_for(visit.customer_id, visit.visit_id)
	if job == null or not NpcDeliveryOfferService.accept(job.job_id):
		return false
	body.show_message("Жду у дома до сна. Адрес: " + NpcPopulationQueries.place_name(job.address_id) + " · доплата " + str(job.bonus))
	return true
#endregion

#region Встреча и общая выдача
## Вызывает отсутствующего получателя у своей двери или направляет видимого NPC домой.
static func knock(player: Entity, door: Entity) -> bool:
	if not GrabService.holder_available(player) or player.has_component(C_Death) or not EntityAvailability.contains(door, ECS.world):
		return false

	var address: C_NpcAddress = door.get_component(C_NpcAddress) as C_NpcAddress
	var job: NpcHomeDelivery = HomeMeetingQueries.job_for_address(address.address_id) if address != null else null
	if job == null:
		return false

	NpcPerceptionService.action_noise(door, NpcPopulationQueries.current().definition.interaction_noise_radius)
	var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(job.npc_id)
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
	if body == null or person == null or person.death_day != 0 or visit == null or CombatService.target_for(body) != null:
		return false

	if HomeMeetingQueries.meeting_for(body) != null:
		if NpcDeliveryScenarioService.armed_for(body) == null:
			CustomerFlowService.try_automatic_handoff(body, visit)
		return true
	if body.has_component(C_CustomerAgent):
		return false

	if person.placement != NpcRecord.Placement.STREET:
		body.place_at(NpcPopulationQueries.position_for(person.home_id))
		DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)


	var service: C_CustomerAgent = C_CustomerAgent.new()
	service.visit_id = visit.visit_id
	service.phase = C_CustomerAgent.Phase.APPROACHING
	body.add_component(service)
	CustomerActionRecipe.install(body)
	var meeting: R_NpcHomeMeeting = R_NpcHomeMeeting.new()
	meeting.job_id = job.job_id
	body.add_relationship(Relationship.new(meeting, door))
	visit.started = true
	visit.finished = false
	visit.visit_count += 1
	visit.last_visit_day = job.day_index
	CustomerParcelAssignment.bind_parcel(body, visit)
	NpcIntentService.move_to(body, NpcPopulationQueries.position_for(job.address_id), visit.definition.arrival_distance)
	body.show_message(person.display_name + " · иду к двери")
	return true

## Фиксирует обычную оплату и доплату с раздельными ключами однократного начисления.
static func complete(job: NpcHomeDelivery) -> bool:
	if job == null:
		return false
	if job.status != NpcHomeDelivery.Status.ACCEPTED:
		return job.status in [NpcHomeDelivery.Status.DELIVERED, NpcHomeDelivery.Status.REFUSED]

	var visit: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if visit == null or cycle == null or visit.actual not in [CustomerVisit.Actual.DELIVERED, CustomerVisit.Actual.CUSTOMER_REFUSED]:
		return false

	if visit.actual == CustomerVisit.Actual.DELIVERED:
		CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.TAKEN)
		CustomerOutcomeService.settle(visit, WalletService.current(), cycle.day_index)
		if not visit.settlement_committed:
			return false

		var operation: MoneyOperation = MoneyOperation.new()
		operation.operation_id = StringName("bonus/" + String(job.job_id))
		operation.settlement_id = job.job_id
		operation.amount = job.bonus
		operation.day_index = cycle.day_index
		operation.note = "Вечерняя доставка " + String(job.address_id)
		var result: WalletService.Status = WalletService.submit(operation)
		if result not in [WalletService.Status.COMMITTED, WalletService.Status.DUPLICATE]:
			return false

		job.bonus_committed = true
		job.status = NpcHomeDelivery.Status.DELIVERED
	else:
		job.status = NpcHomeDelivery.Status.REFUSED

	var body: E_DistrictNpc = NpcPopulationQueries.body_for(job.npc_id)
	if body != null:
		HomeMeetingBindings.release_meeting(body)
		NpcServiceRole.finish_appearance(body, visit)
	return true

#endregion

#region Завершение вечера и отображение
## Завершает обещания один раз; false требует повторить незавершённую оплату до подготовки утра.
static func finish_evening(day_index: int) -> bool:
	var district: C_District = NpcPopulationQueries.current()
	if district == null:
		return true

	var settled: bool = true

	for job: NpcHomeDelivery in district.home_deliveries:
		if job.day_index != day_index:
			continue
		if job.status == NpcHomeDelivery.Status.OFFERED:
			job.status = NpcHomeDelivery.Status.EXPIRED
			continue
		if job.status != NpcHomeDelivery.Status.ACCEPTED:
			continue

		var visit: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
		if visit != null and visit.actual in [CustomerVisit.Actual.DELIVERED, CustomerVisit.Actual.CUSTOMER_REFUSED]:
			if not complete(job):
				settled = false
			continue

		job.status = NpcHomeDelivery.Status.FAILED
		var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(job.npc_id)
		var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
		if person != null and person.death_day == 0:
			if job.source == NpcHomeDelivery.Source.PERSONAL:
				NpcSocialService.remember_promise(person, player, body, job.job_id)
			else:
				NpcSocialService.remember(person, player, body, NpcMemory.Kind.BROKEN_PROMISE, job.job_id)
		if body != null:
			CustomerInspectionService.end(body)
			HomeMeetingBindings.release_meeting(body)
			if visit != null:
				NpcServiceRole.release(body, visit.visit_id)
		# Явный LOST/REFUSED/TAKEN и уже известный спор остаются под властью журнала обслуживания.
		if visit != null and not visit.customer_dead and visit.actual == CustomerVisit.Actual.NOT_RESOLVED and visit.declaration == CustomerVisit.Declaration.NONE and visit.complaint == null:
			visit.started = false
			visit.finished = false
			visit.finished_day = 0
			visit.arrival_day = day_index + 1
			visit.next_followup_day = 0
			visit.followup_committed = false

	return settled

## Краткий список авторитетных обязательств для HUD без внутренних деталей реализации.
static func status_text() -> String:
	var district: C_District = NpcPopulationQueries.current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if district == null or cycle == null:
		return ""

	var lines: PackedStringArray = []
	for job: NpcHomeDelivery in district.home_deliveries:
		if job.day_index == cycle.day_index and job.status <= NpcHomeDelivery.Status.FAILED:
			var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
			var states: PackedStringArray = ["до сна", "доставлено", "получатель отказался", "не выполнено"]
			lines.append("%s · %s · №%03d · +%d · %s" % [person.display_name if person != null else "Получатель", NpcPopulationQueries.place_name(job.address_id), job.order_number, job.bonus, states[job.status]])
	return "" if lines.is_empty() else "Доставка домой\n" + "\n".join(lines)
#endregion
