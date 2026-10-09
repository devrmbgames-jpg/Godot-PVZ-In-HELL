extends RefCounted
## Узкие операции поиска, ухода и наблюдения; приоритет и выбор задаёт Behavior Tree.
class_name NpcDecisionService

const ARRIVAL_DISTANCE: float = 0.3
const COMBAT_STOP_DISTANCE: float = 1.2


#region Meaningful coalesced wake
## Coalesces a due wake; urgent facts invalidate a stale queued step once.
static func request_wake(actor: E_DistrictNpc, reason: StringName, urgent: bool = false) -> void:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	assert(decision != null, "NPC wake requires its constructed decision capability")
	if urgent and not decision.wake_urgent:
		decision.lifecycle_generation += 1
		decision.scheduled_delta = 0.0
	decision.wake_requested = true
	decision.wake_reason = reason
	decision.wake_urgent = decision.wake_urgent or urgent
#endregion


#region Геометрия целей
## Проверяет прибытие по земле, не требуя точного совпадения высоты маркера.
static func at_destination(
	actor: E_DistrictNpc,
	destination: Vector3,
	arrival_distance: float,
) -> bool:
	var offset: Vector3 = destination - actor.global_position
	offset.y = 0.0
	return offset.length_squared() <= arrival_distance * arrival_distance


## Возвращает авторский радиус выхода либо обычное расстояние прибытия.
static func schedule_distance(person: NpcRecord) -> float:
	var district: C_District = NpcPopulationQueries.current()
	var place: DEF_DistrictPlace = district.definition.place_for(person.goal_id)
	return (
		district.definition.portal_arrival_distance
		if (place != null and place.kind == DEF_DistrictPlace.Kind.PORTAL)
		else ARRIVAL_DISTANCE
	)


## Формирует ограниченный список укрытий один раз при начале поиска.
static func search_points(person: NpcRecord, last_position: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = [last_position]
	var covers: Array[Vector3] = []
	for place: DEF_DistrictPlace in NpcPopulationQueries.current().definition.places:
		if place.kind == DEF_DistrictPlace.Kind.COVER:
			var candidate: Vector3 = NpcPopulationQueries.position_for(place.key)
			if candidate.distance_squared_to(last_position) < person.profile.vision_range * person \
					.profile \
					.vision_range:
				covers.append(candidate)
	covers.sort_custom(
		func(first: Vector3, second: Vector3) -> bool:
			return first.distance_squared_to(last_position) < second.distance_squared_to(
				last_position
			),
	)
	for point: Vector3 in covers:
		if points.size() >= person.profile.search_point_count:
			break
		points.append(point)
	return points
#endregion


#region Выход из района
## Продолжает уход к выбранному проходу; возвращает true только после достижения выхода.
static func flee(actor: E_DistrictNpc, person: NpcRecord, awareness: C_NpcAwareness) -> bool:
	awareness.fleeing = true
	if CombatQueries.target_for(actor) != null:
		CombatService.end_combat(actor)

	var district: C_District = NpcPopulationQueries.current()
	var actor_position: Vector3 = (actor as Node as Node3D).global_position
	var portal: StringName = awareness.flee_portal_id
	if portal.is_empty():
		portal = person.portal_id
		var best: float = -INF
		for place: DEF_DistrictPlace in district.definition.places:
			if place.kind != DEF_DistrictPlace.Kind.PORTAL:
				continue

			var candidate: Vector3 = NpcPopulationQueries.position_for(place.key)
			var distance_from_threat: float = candidate.distance_to(awareness.last_seen_position)
			var safety: float = distance_from_threat - actor_position.distance_to(candidate)
			if safety > best:
				best = safety
				portal = place.key
		awareness.flee_portal_id = portal
	var destination: Vector3 = NpcPopulationQueries.position_for(portal)
	if at_destination(actor, destination, district.definition.portal_arrival_distance):
		var interruption: NpcRoleInterruptionRequest = NpcRoleInterruptionRequest.new(
			NpcRoleInterruptionRequest.Kind.FLEE_EXIT
		)
		ECS.world.emit_event(NpcRoleInterruptionRequest.EVENT, actor, interruption)
		CombatService.end_combat(actor)
		var completion: NpcScheduleCompletionRequest = DistrictPopulationService \
				.request_phase_completion(actor, NpcRecord.Placement.OUTSIDE)
		if not completion.completed or not completion.succeeded:
			return false
		awareness.fleeing = false
		awareness.flee_portal_id = &""
		awareness.has_last_seen = false
		return true

	NpcIntentArbiter.move_to(
		actor,
		destination,
		district.definition.portal_arrival_distance,
		C_NpcDecision.Owner.EMERGENCY,
	)

	return false

#endregion


#region Наблюдение
## Окликает воспринимаемого игрока и наблюдает авторское окружение.
static func observe(actor: E_DistrictNpc, person: NpcRecord, awareness: C_NpcAwareness) -> void:
	if awareness.player_visible:
		var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
		if player != null:
			if (
				not awareness.called_out
				and actor.global_position.distance_to((player as Node as Node3D).global_position)
				<= NpcPopulationQueries \
						.current() \
						.definition \
						.conversation_range
			):
				awareness.called_out = true
				actor.show_message(person.display_name + " · Эй, как дела? Подойди, поговорим.")
				NpcPerceptionService.emit_noise(
					actor,
					actor.global_position,
					person.profile.hearing_range * 0.5,
				)
			NpcIntentService.watch(actor, player, Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
	NpcActivityService.observe(actor, person, awareness.player_visible)
#endregion
