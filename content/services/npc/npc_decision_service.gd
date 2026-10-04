extends RefCounted
## Ветки LimboAI запрашивают смысловые действия через единственного владельца намерений.
class_name NpcDecisionService

const ARRIVAL_DISTANCE: float = 0.3
const COMBAT_STOP_DISTANCE: float = 1.2

#region Ветки решений
## Выполняет подходящую ветку; дерево владеет приоритетом и прерыванием.
static func execute_branch(actor: E_DistrictNpc, owner_kind: C_NpcDecision.Owner, delta: float) -> bool:
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id)
	if person == null or person.death_day != 0 or person.placement != NpcRecord.Placement.STREET:
		return false

	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	match owner_kind:
		C_NpcDecision.Owner.EMERGENCY:
			if awareness.hazard_distress:
				NpcIntentArbiter.acquire(actor, owner_kind, "Выйти из опасной зоны")
				NpcIntentArbiter.move_to(actor, NpcRouteService.refuge(actor), ARRIVAL_DISTANCE, owner_kind)
				return true
			if awareness.light_distress and not awareness.fleeing and CombatService.target_for(actor) == null:
				NpcIntentArbiter.acquire(actor, owner_kind, "Укрыться от света")
				NpcIntentArbiter.move_to(actor, NpcTraitService.dark_refuge(actor, person), ARRIVAL_DISTANCE, owner_kind)
				return true

			var health: C_Health = actor.get_component(C_Health) as C_Health
			if not awareness.fleeing and not (CombatService.target_for(actor) != null and health.current < health.value * person.profile.pursuit_health_reserve):
				return false

			NpcIntentArbiter.acquire(actor, owner_kind, "Бегство")
			_flee(actor, person, awareness)
			return true

		C_NpcDecision.Owner.COMBAT:
			if CombatService.target_for(actor) == null:
				return false

			NpcIntentArbiter.acquire(actor, owner_kind, "Преследование" if awareness.target_visible else "Поиск")
			_combat(actor, person, awareness, delta)
			return true

		C_NpcDecision.Owner.SERVICE:
			var participant: Entity = NpcDialogueService.participant(actor)
			var home_job: NpcHomeDelivery = NpcHomeDeliveryService.meeting_for(actor)
			if home_job != null:
				NpcHomeDeliveryService.step(actor, home_job, delta)
				return true

			var service_agent: C_CustomerAgent = actor.get_component(C_CustomerAgent) as C_CustomerAgent
			if service_agent != null and (participant == null or service_agent.phase == C_CustomerAgent.Phase.DIALOGUE):
				NpcIntentArbiter.acquire(actor, owner_kind, "Обслуживание")
				CustomerFlowService.step_service(actor, DayPhaseService.current(), delta)
				return true
			if participant != null:
				NpcIntentArbiter.acquire(actor, owner_kind, "Разговор")
				NpcIntentArbiter.stop(actor, owner_kind)
				if NpcPerceptionService.can_see(actor, participant, person.profile):
					NpcIntentService.watch(actor, participant, Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
				return true
			return false

		C_NpcDecision.Owner.SCHEDULE:
			if person.phase_complete:
				return false

			NpcIntentArbiter.acquire(actor, owner_kind, "Расписание")
			var destination: Vector3 = DistrictPopulationService.position_for(person.goal_id)
			var place: DEF_DistrictPlace = DistrictPopulationService.current().definition.place_for(person.goal_id)
			var arrival_distance: float = DistrictPopulationService.current().definition.portal_arrival_distance if place != null and place.kind == DEF_DistrictPlace.Kind.PORTAL else ARRIVAL_DISTANCE
			if _at_destination(actor, destination, arrival_distance):
				DistrictPopulationService.complete_phase(person, actor)
			else:
				NpcIntentArbiter.move_to(actor, destination, arrival_distance, owner_kind)
			return true

		C_NpcDecision.Owner.IDLE:
			NpcIntentArbiter.acquire(actor, owner_kind, "Свободное занятие")
			_idle(actor, person, awareness, delta)
			return true
	return false
#endregion

#region Бой и бегство
## Прибытие проверяется по земле, как в S_NpcIntent; высота маркера не удерживает NPC на карте.
static func _at_destination(actor: E_DistrictNpc, destination: Vector3, arrival_distance: float) -> bool:
	var offset: Vector3 = destination - actor.global_position
	offset.y = 0.0
	return offset.length_squared() <= arrival_distance * arrival_distance

static func _flee(actor: E_DistrictNpc, person: NpcRecord, awareness: C_NpcAwareness) -> void:
	awareness.fleeing = true
	if CombatService.target_for(actor) != null:
		CombatService.end_combat(actor)

	var district: C_District = DistrictPopulationService.current()
	var actor_position: Vector3 = (actor as Node as Node3D).global_position
	var portal: StringName = awareness.flee_portal_id
	if portal.is_empty():
		portal = person.portal_id
		var best: float = -INF
		for place: DEF_DistrictPlace in district.definition.places:
			if place.kind != DEF_DistrictPlace.Kind.PORTAL:
				continue

			var candidate: Vector3 = DistrictPopulationService.position_for(place.key)
			var safety: float = candidate.distance_to(awareness.last_seen_position) - actor_position.distance_to(candidate)
			if safety > best:
				best = safety
				portal = place.key
		awareness.flee_portal_id = portal
	var destination: Vector3 = DistrictPopulationService.position_for(portal)
	if _at_destination(actor, destination, district.definition.portal_arrival_distance):
		var agent: C_CustomerAgent = actor.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent != null:
			var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
			if visit != null:
				NpcServiceRole.finish_appearance(actor, visit)
		CombatService.end_combat(actor)
		awareness.fleeing = false
		awareness.flee_portal_id = &""
		awareness.has_last_seen = false
		person.phase_complete = true
		DistrictPopulationService.set_placement(person, actor, NpcRecord.Placement.OUTSIDE)
		return

	NpcIntentArbiter.move_to(actor, destination, district.definition.portal_arrival_distance, C_NpcDecision.Owner.EMERGENCY)

static func _combat(actor: E_DistrictNpc, person: NpcRecord, awareness: C_NpcAwareness, _delta: float) -> void:
	var opponent: Entity = CombatService.target_for(actor)
	if not GrabService.holder_available(opponent):
		CombatService.end_combat(actor)
		awareness.has_last_seen = false
		return
	if not awareness.target_visible:
		if not awareness.has_last_seen or awareness.search_elapsed >= person.profile.search_seconds:
			CombatService.end_combat(actor)
			awareness.has_last_seen = false
			return

		var search_point: Vector3 = awareness.last_seen_position
		awareness.search_index = mini(person.profile.search_point_count - 1, int(awareness.search_elapsed / (person.profile.search_seconds / person.profile.search_point_count)))
		if awareness.search_index > 0:
			var district: C_District = DistrictPopulationService.current()
			var covers: Array[DEF_DistrictPlace] = []
			for place: DEF_DistrictPlace in district.definition.places:
				if place.kind == DEF_DistrictPlace.Kind.COVER and DistrictPopulationService.position_for(place.key).distance_to(awareness.last_seen_position) < person.profile.vision_range:
					covers.append(place)
			covers.sort_custom(func(first: DEF_DistrictPlace, second: DEF_DistrictPlace) -> bool:
				return DistrictPopulationService.position_for(first.key).distance_squared_to(awareness.last_seen_position) < DistrictPopulationService.position_for(second.key).distance_squared_to(awareness.last_seen_position)

			)
			if not covers.is_empty():
				search_point = DistrictPopulationService.position_for(covers[mini(awareness.search_index - 1, covers.size() - 1)].key)
		NpcIntentArbiter.move_to(actor, search_point, ARRIVAL_DISTANCE, C_NpcDecision.Owner.COMBAT)
		return

	var combat: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if combat.phase != C_NpcCombat.Phase.READY:
		return

	var choice: NpcAttackChoice = NpcAttackService.choose(actor)
	if choice != null:
		NpcAttackService.start(actor, choice.kind, choice.variant)
	else:
		NpcIntentArbiter.move_to(actor, awareness.last_seen_position, COMBAT_STOP_DISTANCE, C_NpcDecision.Owner.COMBAT)
#endregion

#region Свободные занятия
static func _idle(actor: E_DistrictNpc, person: NpcRecord, awareness: C_NpcAwareness, delta: float) -> void:
	if not person.profile.merchant and NpcCommunityService.idle(actor, person):
		return
	if awareness.heard_remaining > 0.0 and awareness.investigate_noise and not person.profile.merchant:
		NpcIntentArbiter.move_to(actor, awareness.heard_position, ARRIVAL_DISTANCE, C_NpcDecision.Owner.IDLE)
		return

	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent.movement_active and not intent.arrived:
		return

	NpcIntentArbiter.stop(actor, C_NpcDecision.Owner.IDLE)
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if awareness.player_visible and player != null:
		if not awareness.called_out and actor.global_position.distance_to((player as Node as Node3D).global_position) <= DistrictPopulationService.current().definition.conversation_range:
			awareness.called_out = true
			actor.show_message(person.display_name + " · Эй, как дела? Подойди, поговорим.")
			NpcPerceptionService.emit_noise(actor, actor.global_position, person.profile.hearing_range * 0.5)
		NpcIntentService.watch(actor, player, Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
	NpcActivityService.observe(actor, person, awareness.player_visible)
	awareness.idle_elapsed += delta

	var district: C_District = DistrictPopulationService.current()
	if person.profile.merchant or awareness.idle_elapsed < district.definition.activity_seconds:
		return

	awareness.idle_elapsed = 0.0
	person.activity_sequence += 1
	var destination: DEF_DistrictPlace = NpcActivityService.choose(actor, person)
	if destination != null:
		person.goal_id = destination.key
		NpcIntentArbiter.move_to(actor, NpcActivityService.destination(destination), ARRIVAL_DISTANCE, C_NpcDecision.Owner.IDLE)
#endregion
