extends RefCounted
## Data-driven free destinations and observation, separate from parcel service.
class_name NpcActivityService

#region Destinations
## Returns a visitor standing point clear of the merchant.
static func destination(place: DEF_DistrictPlace) -> Vector3:
	return DistrictPopulationService.position_for(place.key) + place.activity_offset

## Selects a preferred eligible activity deterministically at its next interval.
static func choose(actor: E_DistrictNpc, person: NpcRecord) -> DEF_DistrictPlace:
	var candidates: Array[DEF_DistrictPlace] = []
	for place: DEF_DistrictPlace in DistrictPopulationService.current().definition.places:
		if place.kind not in [DEF_DistrictPlace.Kind.ACTIVITY, DEF_DistrictPlace.Kind.SHOP] or not person.profile.preferred_activities.has(place.activity):
			continue
		if place.activity == DEF_DistrictPlace.Activity.VISIT_SHOP and merchant() == null:
			continue

		var light_rule: DEF_NpcTrait = person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION)
		if light_rule != null and NpcLightingService.exposure_at(destination(place) + Vector3.UP, [actor.get_rid()]) > light_rule.light_threshold:
			continue
		candidates.append(place)

	return candidates[abs(hash(person.npc_id) + person.activity_sequence) % candidates.size()] if not candidates.is_empty() else null

## Resolves a living participating shopkeeper; a vacant shop is not a destination.
static func merchant() -> E_DistrictNpc:
	for person: NpcRecord in DistrictPopulationService.current().people:
		if person.death_day == 0 and person.placement == NpcRecord.Placement.STREET and person.profile.merchant:
			return DistrictPopulationService.body_for(person.npc_id)
	return null
#endregion

#region Observation
## Applies stationary focus without tracking an unseen player.
static func observe(actor: E_DistrictNpc, person: NpcRecord, player_visible: bool) -> void:
	var place: DEF_DistrictPlace = DistrictPopulationService.current().definition.place_for(person.goal_id)
	if place == null or player_visible:
		return

	NpcIntentService.look_along_movement(actor)
	if place.activity == DEF_DistrictPlace.Activity.OBSERVE:
		var subject: E_DistrictNpc = null
		var nearest: float = INF
		for record: NpcRecord in DistrictPopulationService.current().people:
			if record.death_day != 0 or record.placement != NpcRecord.Placement.STREET:
				continue
			var candidate: E_DistrictNpc = DistrictPopulationService.body_for(record.npc_id)
			if candidate == null or not NpcPerceptionService.can_see(actor, candidate, person.profile):
				continue
			var distance: float = actor.global_position.distance_squared_to(candidate.global_position)
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
