extends RefCounted
## Voluntary home delivery reuses ordinary parcel acceptance and pays one distinct bonus.
class_name NpcHomeDeliveryService

#region Obligations
## Finds a suitable registered unresolved case for this permanent local person.
static func offer_for(body: E_DistrictNpc) -> CustomerVisit:
	var district: C_District = DistrictPopulationService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	var person: NpcRecord = DistrictPopulationService.person_for(NpcSocialService.identity_for(body))
	var flow: C_CustomerFlow = CustomerFlowService.current()
	if district == null or cycle == null or flow == null or person == null or not person.profile.resident or person.death_day != 0 or cycle.phase not in [C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		return null
	var accepted: int = 0
	for job: NpcHomeDelivery in district.home_deliveries:
		if job.day_index == cycle.day_index:
			accepted += 1
	if accepted >= district.definition.maximum_home_deliveries:
		return null
	for visit: CustomerVisit in flow.visits:
		if visit.customer_id != person.npc_id or visit.customer_dead or visit.actual != CustomerVisit.Actual.NOT_RESOLVED or visit.declaration != CustomerVisit.Declaration.NONE or visit.settlement_committed or visit.complaint != null or not CustomerFlowService.arrival_allowed(visit) or CustomerFlowService.parcel_for(visit.package_id) == null:
			continue
		var already_promised: bool = false
		for job: NpcHomeDelivery in district.home_deliveries:
			if job.visit_id == visit.visit_id and job.day_index == cycle.day_index:
				already_promised = true
		if not already_promised:
			var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
			var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
			if state != null and state.registration == C_PackageState.Registration.REGISTERED and CustomerPresentation.registered_number(visit) > 0:
				return visit
	return null

## Accepts at most the authored limit and suspends the daytime counter appearance.
static func accept(body: E_DistrictNpc) -> bool:
	var visit: CustomerVisit = offer_for(body)
	if visit == null:
		return false
	var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
	var cycle: C_DayCycle = DayPhaseService.current()
	var job: NpcHomeDelivery = NpcHomeDelivery.new()
	job.job_id = StringName("home/%d/%s" % [cycle.day_index, visit.visit_id])
	job.npc_id = person.npc_id
	job.visit_id = visit.visit_id
	job.address_id = person.home_id
	job.order_number = CustomerPresentation.registered_number(visit)
	job.day_index = cycle.day_index
	DistrictPopulationService.current().home_deliveries.append(job)
	CustomerInspectionService.end(body)
	NpcServiceRole.release(body, visit.visit_id)
	visit.finished = true
	visit.finished_day = cycle.day_index
	visit.next_followup_day = cycle.day_index + 1
	visit.followup_committed = true
	person.planned_phase = -1
	body.show_message("Жду у дома до сна. Адрес: " + DistrictPopulationService.place_name(job.address_id) + " · доплата " + str(visit.payment))
	return true

## Active address job exists only in its evening and never transfers to a replacement.
static func job_for_address(address_id: StringName) -> NpcHomeDelivery:
	var district: C_District = DistrictPopulationService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if district == null or cycle == null or cycle.phase != C_DayCycle.Phase.EVENING:
		return null
	for job: NpcHomeDelivery in district.home_deliveries:
		if job.address_id == address_id and job.day_index == cycle.day_index and job.status == NpcHomeDelivery.Status.ACCEPTED:
			return job
	return null

## Returns the obligation only while a live relationship reserves its door.
static func meeting_for(body: Entity) -> NpcHomeDelivery:
	if not is_instance_valid(body):
		return null
	for link: Relationship in body.relationships:
		if link.relation is R_NpcHomeMeeting and EntityAvailability.contains(link.target, ECS.world):
			for job: NpcHomeDelivery in DistrictPopulationService.current().home_deliveries:
				if job.job_id == (link.relation as R_NpcHomeMeeting).job_id and job.status == NpcHomeDelivery.Status.ACCEPTED:
					return job
	return null

## Returns a live home door when inspection needs to return to the meeting.
static func door_for(body: Entity) -> Entity:
	for link: Relationship in body.relationships:
		if link.relation is R_NpcHomeMeeting and EntityAvailability.contains(link.target, ECS.world):
			return link.target as Entity
	return null
#endregion

#region Meeting and shared receipt
## Wakes an absent recipient at their own door, or asks a visible recipient to walk home.
static func knock(player: Entity, door: Entity) -> bool:
	var address: C_NpcAddress = door.get_component(C_NpcAddress) as C_NpcAddress
	var job: NpcHomeDelivery = job_for_address(address.address_id) if address != null else null
	if job == null:
		return false
	NpcPerceptionService.action_noise(door, DistrictPopulationService.current().definition.interaction_noise_radius)
	var person: NpcRecord = DistrictPopulationService.person_for(job.npc_id)
	var body: E_DistrictNpc = DistrictPopulationService.body_for(job.npc_id)
	var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
	if body == null or person == null or person.death_day != 0 or visit == null or CombatService.target_for(body) != null:
		return false
	if meeting_for(body) != null:
		CustomerFlowService.try_automatic_handoff(body, visit)
		return true
	if body.has_component(C_CustomerAgent):
		return false
	if person.placement != NpcRecord.Placement.STREET:
		body.place_at(DistrictPopulationService.position_for(person.home_id))
		DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	var service: C_CustomerAgent = C_CustomerAgent.new()
	service.visit_id = visit.visit_id
	service.phase = C_CustomerAgent.Phase.APPROACHING
	body.add_component(service)
	var meeting: R_NpcHomeMeeting = R_NpcHomeMeeting.new()
	meeting.job_id = job.job_id
	body.add_relationship(Relationship.new(meeting, door))
	visit.started = true
	visit.finished = false
	visit.visit_count += 1
	visit.last_visit_day = job.day_index
	CustomerFlowService.bind_parcel(body, visit)
	NpcIntentService.move_to(body, DistrictPopulationService.position_for(job.address_id), visit.definition.arrival_distance)
	body.show_message(person.display_name + " · иду к двери")
	return GrabService.holder_available(player)

## Runs the home service branch with no patience timer or counter relocation.
static func step(body: E_DistrictNpc, job: NpcHomeDelivery, delta: float) -> void:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
	if agent == null or visit == null:
		return
	NpcIntentArbiter.acquire(body, C_NpcDecision.Owner.SERVICE, "Доставка у двери")
	agent.elapsed += delta
	if visit.actual in [CustomerVisit.Actual.DELIVERED, CustomerVisit.Actual.CUSTOMER_REFUSED]:
		complete(job)
		return
	match agent.phase:
		C_CustomerAgent.Phase.APPROACHING:
			var intent: C_NpcIntent = body.get_component(C_NpcIntent) as C_NpcIntent
			if intent.arrived:
				agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
				agent.elapsed = 0.0
				NpcIntentArbiter.stop(body, C_NpcDecision.Owner.SERVICE)
				body.show_message(CustomerPresentation.request_text(visit))
		C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
			CustomerFlowService.try_automatic_handoff(body, visit)
		C_CustomerAgent.Phase.GOING_TO_BOOTH, C_CustomerAgent.Phase.INSPECTING, C_CustomerAgent.Phase.RETURNING_FROM_BOOTH:
			if CustomerInspectionService.tick(body, visit):
				CustomerFlowService.complete_inspection(body, visit)

## Commits ordinary settlement and bonus with distinct idempotency identities.
static func complete(job: NpcHomeDelivery) -> bool:
	if job.status != NpcHomeDelivery.Status.ACCEPTED:
		return job.status == NpcHomeDelivery.Status.DELIVERED
	var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
	var cycle: C_DayCycle = DayPhaseService.current()
	if visit == null or cycle == null or visit.actual not in [CustomerVisit.Actual.DELIVERED, CustomerVisit.Actual.CUSTOMER_REFUSED]:
		return false
	if visit.actual == CustomerVisit.Actual.DELIVERED:
		CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.TAKEN)
		CustomerOutcomeService.settle(visit, WalletService.current(), cycle.day_index)
		var operation: MoneyOperation = MoneyOperation.new()
		operation.operation_id = StringName("bonus/" + String(job.job_id))
		operation.settlement_id = job.job_id
		operation.amount = visit.payment
		operation.day_index = cycle.day_index
		operation.note = "Вечерняя доставка " + String(job.address_id)
		var result: WalletService.Status = WalletService.submit(operation)
		if result not in [WalletService.Status.COMMITTED, WalletService.Status.DUPLICATE]:
			return false
		job.bonus_committed = true
		job.status = NpcHomeDelivery.Status.DELIVERED
	else:
		job.status = NpcHomeDelivery.Status.REFUSED
	var body: E_DistrictNpc = DistrictPopulationService.body_for(job.npc_id)
	if body != null:
		release_meeting(body)
		NpcServiceRole.finish_appearance(body, visit)
	return true

## Drops only the meeting reservation; it does not move the parcel.
static func release_meeting(body: Entity) -> void:
	for link: Relationship in body.relationships.duplicate():
		if link.relation is R_NpcHomeMeeting:
			body.remove_relationship(link)
#endregion

#region Night closeout and presentation
## Resolves unfulfilled promises once; registered physical boxes remain in place.
static func finish_evening(day_index: int) -> void:
	var district: C_District = DistrictPopulationService.current()
	if district == null:
		return
	for job: NpcHomeDelivery in district.home_deliveries:
		if job.day_index != day_index or job.status != NpcHomeDelivery.Status.ACCEPTED:
			continue
		var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
		if visit != null and visit.actual in [CustomerVisit.Actual.DELIVERED, CustomerVisit.Actual.CUSTOMER_REFUSED]:
			complete(job)
			continue
		job.status = NpcHomeDelivery.Status.FAILED
		var person: NpcRecord = DistrictPopulationService.person_for(job.npc_id)
		var body: E_DistrictNpc = DistrictPopulationService.body_for(job.npc_id)
		var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
		if person != null and person.death_day == 0:
			NpcSocialService.remember(person, player, body, NpcMemory.Kind.BROKEN_PROMISE, job.job_id)
		if body != null:
			CustomerInspectionService.end(body)
			release_meeting(body)
			if visit != null:
				NpcServiceRole.release(body, visit.visit_id)
		if visit != null and not visit.customer_dead:
			visit.started = false
			visit.finished = false
			visit.finished_day = 0
			visit.arrival_day = day_index + 1
			visit.next_followup_day = 0
			visit.followup_committed = false

## Concise authoritative job list for the HUD; no internal implementation details.
static func status_text() -> String:
	var district: C_District = DistrictPopulationService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if district == null or cycle == null:
		return ""
	var lines: PackedStringArray = []
	for job: NpcHomeDelivery in district.home_deliveries:
		if job.day_index == cycle.day_index:
			var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
			var person: NpcRecord = DistrictPopulationService.person_for(job.npc_id)
			var states: PackedStringArray = ["до сна", "доставлено", "получатель отказался", "не выполнено"]
			lines.append("%s · %s · №%03d · +%d · %s" % [person.display_name if person != null else "Получатель", DistrictPopulationService.place_name(job.address_id), job.order_number, visit.payment if visit != null else 0, states[job.status]])
	return "" if lines.is_empty() else "Доставка домой\n" + "\n".join(lines)
#endregion
