extends RefCounted
## Parcel service is a temporary role of a permanent person, with exclusive counter reservation.
class_name NpcServiceRole

const QUEUE_SPACING: float = 1.3

#region Service scheduling
## Enqueues one registered case without creating or resetting its recipient.
static func enqueue_next(flow: C_CustomerFlow, cycle: C_DayCycle) -> bool:
	if cycle.phase != C_DayCycle.Phase.DAY or flow.arrival_cooldown_seconds > 0.0:
		return false
	for visit: CustomerVisit in flow.visits:
		if visit.started or visit.finished or visit.customer_dead or visit.arrival_day > cycle.day_index or not CustomerFlowService.arrival_allowed(visit):
			continue
		var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
		var body: E_DistrictNpc = DistrictPopulationService.body_for(visit.customer_id)
		if person == null or person.death_day != 0 or body == null or body.has_component(C_CustomerAgent) or CombatService.target_for(body) != null:
			continue
		var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
		if awareness != null and (awareness.fleeing or awareness.hazard_distress or awareness.light_distress):
			continue
		var light_rule: DEF_NpcTrait = person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION)
		var station: E_DeliveryCounter = CustomerFlowService.counter()
		if light_rule != null and station != null and NpcLightingService.exposure_at(station.waiting_position() + Vector3.UP) > light_rule.light_threshold:
			if awareness != null and not awareness.warned_rules.has(light_rule.kind):
				awareness.warned_rules.append(light_rule.kind)
				body.show_message(light_rule.warning_text + " " + light_rule.countermeasure)
			continue
		begin(body, person, visit, cycle.day_index)
		flow.arrival_cooldown_seconds = flow.schedule.arrival_interval_seconds
		return true
	return false

## Attaches an appearance to a retained body and lets the decision tree move it.
static func begin(body: E_DistrictNpc, person: NpcRecord, visit: CustomerVisit, day_index: int) -> void:
	if person.placement != NpcRecord.Placement.STREET:
		body.place_at(DistrictPopulationService.position_for(person.home_id if person.placement == NpcRecord.Placement.HOME else person.portal_id))
		DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	var service: C_CustomerAgent = C_CustomerAgent.new()
	service.visit_id = visit.visit_id
	service.phase = C_CustomerAgent.Phase.QUEUED
	body.add_component(service)
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

## Advances the queue or owns the counter; only the service branch calls this.
static func step_queue(body: E_DistrictNpc, visit: CustomerVisit) -> void:
	var counter: E_DeliveryCounter = CustomerFlowService.counter()
	if counter == null:
		finish_appearance(body, visit)
		return
	var queue: Array[E_DistrictNpc] = []
	var occupied: bool = false
	for entity: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		for link: Relationship in entity.relationships:
			if link.relation is R_NpcServiceAt and link.target == counter:
				occupied = true
		var agent: C_CustomerAgent = entity.get_component(C_CustomerAgent) as C_CustomerAgent
		if entity is E_DistrictNpc and agent.phase == C_CustomerAgent.Phase.QUEUED:
			queue.append(entity as E_DistrictNpc)
	queue.sort_custom(func(first: E_DistrictNpc, second: E_DistrictNpc) -> bool:
		var first_agent: C_CustomerAgent = first.get_component(C_CustomerAgent) as C_CustomerAgent
		var second_agent: C_CustomerAgent = second.get_component(C_CustomerAgent) as C_CustomerAgent
		return CustomerFlowService.find_visit(first_agent.visit_id).queue_order < CustomerFlowService.find_visit(second_agent.visit_id).queue_order
	)
	var index: int = queue.find(body)
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	if index == 0 and not occupied:
		var reservation: R_NpcServiceAt = R_NpcServiceAt.new()
		reservation.visit_id = visit.visit_id
		body.add_relationship(Relationship.new(reservation, counter))
		agent.phase = C_CustomerAgent.Phase.APPROACHING
		agent.elapsed = 0.0
		NpcIntentService.move_to(body, counter.waiting_position(), visit.definition.arrival_distance)
		return
	var direction: Vector3 = (counter.entry_position() - counter.waiting_position()).normalized()
	var destination: Vector3 = counter.waiting_position() + direction * QUEUE_SPACING * float(maxi(1, index + 1))
	NpcIntentArbiter.move_to(body, destination, visit.definition.arrival_distance, C_NpcDecision.Owner.SERVICE)
	if agent.elapsed >= visit.definition.patience_seconds:
		finish_appearance(body, visit)
#endregion

#region Role termination
## Interrupts an unresolved appearance, releasing its cargo and reservation without inventing an outcome.
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
	visit.started = false
	visit.finished = home != null

## Ends only this appearance, preserving the person and unresolved case rules.
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

## Releases the role and only its live parcel/reservation bindings.
static func release(body: Entity, visit_id: StringName) -> void:
	NpcDialogueService.end(body)
	var parcel: Entity = CustomerFlowService.parcel_for(CustomerFlowService.find_visit(visit_id).package_id) if CustomerFlowService.find_visit(visit_id) != null else null
	if parcel != null:
		for link: Relationship in parcel.relationships.duplicate():
			if link.relation is R_AssignedTo and (link.relation as R_AssignedTo).visit_id == visit_id:
				parcel.remove_relationship(link)
	for link: Relationship in body.relationships.duplicate():
		if link.relation is R_NpcServiceAt:
			body.remove_relationship(link)
	if body.has_component(C_CustomerAgent):
		body.remove_component(C_CustomerAgent)

## Propagates a permanent death across every case without transferring ownership.
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

## Adapts existing escalation requests to generic combat targeting.
static func escalate(body: E_DistrictNpc) -> void:
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if player != null:
		var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
		var incident: StringName = StringName("service/%s/offense" % agent.visit_id)
		body.show_message("Вы нарушили условия выдачи. Объяснитесь.")
		NpcSocialService.react(body, player, NpcMemory.Kind.OFFENSE, incident)
#endregion
