extends RefCounted
## Выбор свободных целей и наблюдения по данным, независимо от обслуживания посылок.
class_name NpcActivityService


#region Цели движения
## Возвращает точку посетителя с зазором от торговца.
static func destination(place: DEF_DistrictPlace) -> Vector3:
	return NpcPopulationQueries.position_for(place.key) + place.activity_offset


## Фиксированно выбирает доступное предпочитаемое занятие по истечении паузы.
static func choose(actor: E_DistrictNpc, person: NpcRecord) -> DEF_DistrictPlace:
	var candidates: Array[DEF_DistrictPlace] = []
	for place: DEF_DistrictPlace in NpcPopulationQueries.current().definition.places:
		if (
			place.kind not in [DEF_DistrictPlace.Kind.ACTIVITY, DEF_DistrictPlace.Kind.SHOP]
			or not person.profile.preferred_activities.has(place.activity)
		):
			continue
		if place.activity == DEF_DistrictPlace.Activity.VISIT_SHOP and merchant() == null:
			continue

		var light_rule: DEF_NpcTrait = person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION)
		var exposure: float = (
			NpcLightingService.exposure_at(destination(place) + Vector3.UP, [actor.get_rid()])
			if light_rule != null
			else 0.0
		)
		if (light_rule != null and exposure > light_rule.light_threshold):
			continue

		candidates.append(place)

	if candidates.is_empty():
		return null
	candidates.sort_custom(
		func(a: DEF_DistrictPlace, b: DEF_DistrictPlace) -> bool:
			return String(a.key) < String(b.key),
	)
	var random: RandomNumberGenerator = GameTimeQueries.decision(
		String(person.npc_id),
		DayPhaseQueries.current().day_index,
		"npc/activity",
		person.activity_sequence,
	)
	return candidates[random.randi_range(0, candidates.size() - 1)]


## Находит живого участвующего торговца; пустая торговая точка не является целью.
static func merchant() -> E_DistrictNpc:
	for person: NpcRecord in NpcPopulationQueries.current().people:
		if (
			person.death_day == 0 and person.placement == NpcRecord.Placement.STREET
			and person.profile.merchant
		):
			return NpcPopulationQueries.body_for(person.npc_id)
	return null
#endregion


#region Наблюдение
## Направляет неподвижный взгляд, не отслеживая скрытого игрока.
static func observe(actor: E_DistrictNpc, person: NpcRecord, player_visible: bool) -> void:
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	var place_id: StringName = decision.local_activity_id if not decision \
			.local_activity_id \
			.is_empty() \
			else person.goal_id
	var place: DEF_DistrictPlace = NpcPopulationQueries.current().definition.place_for(place_id)
	if place == null or player_visible:
		return

	NpcIntentService.look_along_movement(actor)
	if place.activity == DEF_DistrictPlace.Activity.OBSERVE:
		var subject: E_DistrictNpc = null
		var nearest: float = INF
		for record: NpcRecord in NpcPopulationQueries.current().people:
			if record.death_day != 0 or record.placement != NpcRecord.Placement.STREET:
				continue

			var candidate: E_DistrictNpc = NpcPopulationQueries.body_for(record.npc_id)
			if (
				candidate == null
				or not NpcPerceptionService.can_see(actor, candidate, person.profile)
			):
				continue

			var distance: float = actor.global_position.distance_squared_to(
				candidate.global_position
			)
			if distance < nearest:
				nearest = distance
				subject = candidate
		if subject != null:
			NpcIntentService.watch(actor, subject, Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
		return

	if place.activity == DEF_DistrictPlace.Activity.VISIT_SHOP:
		var shopkeeper: E_DistrictNpc = merchant()
		if shopkeeper != null and NpcPerceptionService.can_see(actor, shopkeeper, person.profile):
			NpcIntentService.watch(actor, shopkeeper, Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
		return

	if place.activity == DEF_DistrictPlace.Activity.WATCH_WINDOW and not place.focus_path.is_empty():
		var focus: Node3D = ECS.world.get_parent().get_node_or_null(place.focus_path) as Node3D
		if focus != null:
			NpcIntentService.look_at(actor, focus.global_position)
#endregion
