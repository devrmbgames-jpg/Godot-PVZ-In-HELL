extends RefCounted
## LimboAI branch adapters issue semantic intents through a single owner and existing services.
class_name NpcDecisionService

const ARRIVAL_DISTANCE: float = 0.3
const COMBAT_STOP_DISTANCE: float = 1.2
const SEARCH_POINT_COUNT: int = 3

#region Decision branches
## Executes only the applicable branch; the tree owns priority and interruption.
static func execute_branch(actor: E_DistrictNpc, owner_kind: C_NpcDecision.Owner, delta: float) -> bool:
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = DistrictPopulationService.person_for(identity.npc_id)
	if person == null or person.death_day != 0 or person.placement != NpcRecord.Placement.STREET:
		return false
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	match owner_kind:
		C_NpcDecision.Owner.EMERGENCY:
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
			if not actor.has_component(C_CustomerAgent):
				return false
			NpcIntentArbiter.acquire(actor, owner_kind, "Обслуживание")
			CustomerFlowService.step_service(actor, DayPhaseService.current(), delta)
			return true
		C_NpcDecision.Owner.SCHEDULE:
			if person.phase_complete:
				return false
			NpcIntentArbiter.acquire(actor, owner_kind, "Расписание")
			var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
			var destination: Vector3 = DistrictPopulationService.position_for(person.goal_id)
			if intent.arrived and intent.move_position.distance_to(destination) < ARRIVAL_DISTANCE:
				DistrictPopulationService.complete_phase(person, actor)
			else:
				NpcIntentArbiter.move_to(actor, destination, ARRIVAL_DISTANCE, owner_kind)
			return true
		C_NpcDecision.Owner.IDLE:
			NpcIntentArbiter.acquire(actor, owner_kind, "Свободное занятие")
			_idle(actor, person, awareness, delta)
			return true
	return false
#endregion

#region Combat and escape
static func _flee(actor: E_DistrictNpc, person: NpcRecord, awareness: C_NpcAwareness) -> void:
	var district: C_District = DistrictPopulationService.current()
	var actor_position: Vector3 = (actor as Node as Node3D).global_position
	var portal: StringName = person.portal_id
	var best: float = -INF
	for place: DEF_DistrictPlace in district.definition.places:
		if place.kind != DEF_DistrictPlace.Kind.PORTAL:
			continue
		var candidate: Vector3 = DistrictPopulationService.position_for(place.key)
		var safety: float = candidate.distance_to(awareness.last_seen_position) - actor_position.distance_to(candidate)
		if safety > best:
			best = safety
			portal = place.key
	var destination: Vector3 = DistrictPopulationService.position_for(portal)
	if actor_position.distance_to(destination) <= ARRIVAL_DISTANCE:
		var agent: C_CustomerAgent = actor.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent != null:
			var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
			if visit != null:
				NpcServiceRole.finish_appearance(actor, visit)
		CombatService.end_combat(actor)
		awareness.fleeing = false
		awareness.has_last_seen = false
		person.phase_complete = true
		DistrictPopulationService.set_placement(person, actor, NpcRecord.Placement.OUTSIDE)
		return
	NpcIntentArbiter.move_to(actor, destination, ARRIVAL_DISTANCE, C_NpcDecision.Owner.EMERGENCY)

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
		awareness.search_index = mini(SEARCH_POINT_COUNT - 1, int(awareness.search_elapsed / (person.profile.search_seconds / SEARCH_POINT_COUNT)))
		if awareness.search_index > 0:
			var district: C_District = DistrictPopulationService.current()
			var index: int = 0
			for place: DEF_DistrictPlace in district.definition.places:
				var candidate: Vector3 = DistrictPopulationService.position_for(place.key)
				if place.kind == DEF_DistrictPlace.Kind.ACTIVITY and candidate.distance_to(awareness.last_seen_position) < person.profile.vision_range:
					index += 1
					if index == awareness.search_index:
						search_point = candidate
						break
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

#region Free activity
static func _idle(actor: E_DistrictNpc, person: NpcRecord, awareness: C_NpcAwareness, delta: float) -> void:
	if awareness.heard_remaining > 0.0 and not person.profile.merchant:
		NpcIntentArbiter.move_to(actor, awareness.heard_position, ARRIVAL_DISTANCE, C_NpcDecision.Owner.IDLE)
		return
	var intent: C_NpcIntent = actor.get_component(C_NpcIntent) as C_NpcIntent
	if intent.movement_active and not intent.arrived:
		return
	NpcIntentArbiter.stop(actor, C_NpcDecision.Owner.IDLE)
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if awareness.player_visible and player != null:
		NpcIntentService.watch(actor, player, Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
	awareness.idle_elapsed += delta
	var district: C_District = DistrictPopulationService.current()
	if person.profile.merchant or awareness.idle_elapsed < district.definition.activity_seconds:
		return
	awareness.idle_elapsed = 0.0
	person.activity_sequence += 1
	var activities: Array[DEF_DistrictPlace] = []
	for place: DEF_DistrictPlace in district.definition.places:
		if place.kind == DEF_DistrictPlace.Kind.ACTIVITY:
			activities.append(place)
	if not activities.is_empty():
		person.goal_id = activities[abs(hash(person.npc_id) + person.activity_sequence) % activities.size()].key
		NpcIntentArbiter.move_to(actor, DistrictPopulationService.position_for(person.goal_id), ARRIVAL_DISTANCE, C_NpcDecision.Owner.IDLE)
#endregion
