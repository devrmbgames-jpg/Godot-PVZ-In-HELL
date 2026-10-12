extends RefCounted
## Read-only local authored light preference and safe native route selection.
class_name NpcLightComfortSolver


#region Optional local preference
static func rule_for(person: NpcRecord) -> DEF_NpcLightComfort:
	for rule: DEF_NpcTrait in person.rules_for():
		if rule is DEF_NpcLightComfort:
			return rule as DEF_NpcLightComfort
	return null


## Optional comfort never interrupts an obligation, conversation, conflict or immediate danger.
static func available(actor: E_DistrictNpc, person: NpcRecord) -> bool:
	var rule: DEF_NpcLightComfort = rule_for(person)
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	return (
		rule != null and rule.valid_configuration() and person.phase_complete
		and not actor.has_active_role() and NpcDialogueService.participant(actor) == null
		and CombatQueries.target_for(actor) == null and not awareness.fleeing
		and not awareness.hazard_distress and not NpcGazeQueries.frozen(actor)
		and not NpcBloodQueries.calmed(actor)
		and NpcLightingService.exposure_at(
			actor.global_position + Vector3.UP * NpcPerceptionService.TORSO_HEIGHT,
		)
		> rule.discomfort_threshold
	)


## Selects the nearest comfortable local activity/cover with a reachable zero-damage route.
static func destination_for(
	actor: E_DistrictNpc,
	person: NpcRecord,
	rule: DEF_NpcLightComfort,
) -> StringName:
	var map: RID = actor.navigation_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return &""
	var definition: DEF_District = NpcPopulationQueries.current().definition
	var closest: float = rule.search_radius
	var selected: StringName = &""
	for place: DEF_DistrictPlace in definition.places:
		if place.kind not in [DEF_DistrictPlace.Kind.ACTIVITY, DEF_DistrictPlace.Kind.COVER]:
			continue
		var position: Vector3 = NpcPopulationQueries.position_for(place.key, true)
		if not position.is_finite():
			continue
		var distance: float = actor.global_position.distance_to(position)
		if distance <= NpcDecisionService.ARRIVAL_DISTANCE or distance > closest:
			continue
		var exposure: float = NpcLightingService.exposure_at(
			position + Vector3.UP * NpcPerceptionService.TORSO_HEIGHT,
		)
		if exposure > rule.comfortable_threshold:
			continue
		var path: PackedVector3Array = NpcRouteSolver.plan(
			actor,
			person,
			actor.global_position,
			position,
			map,
		)
		if path.is_empty() or NpcRouteSolver.expected_damage(actor, path) > 0.0:
			continue
		closest = distance
		selected = place.key
	return selected
#endregion
