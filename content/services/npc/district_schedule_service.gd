extends RefCounted
## Commits phase anchors and terminal population facts outside ECS iteration.
class_name DistrictScheduleService

#region Schedule processing
## Advances placement without progressing the player-controlled calendar.
static func tick(district: C_District, cycle: C_DayCycle) -> void:
	if district.definition == null or cycle.phase == C_DayCycle.Phase.NIGHT:
		return
	var phase_key: StringName = StringName("%d/%d" % [cycle.day_index, cycle.phase])
	if district.conflict_phase != phase_key:
		district.conflict_phase = phase_key
		district.ambient_conflicts = 0
	for person: NpcRecord in district.people.duplicate():
		var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
		if body == null or person.death_day != 0:
			continue
		if body.has_component(C_Death):
			DistrictPopulationService.mark_dead(person, body, cycle.day_index)
			continue
		if body.has_component(C_CustomerAgent):
			continue
		DistrictPopulationService.plan_phase(person, cycle.day_index, cycle.phase)
		if person.placement != NpcRecord.Placement.STREET:
			continue
		var intent: C_NpcIntent = body.get_component(C_NpcIntent) as C_NpcIntent
		if not person.phase_complete:
			if intent.arrived and intent.move_position.distance_to(DistrictPopulationService.position_for(person.goal_id)) < 0.1:
				DistrictPopulationService.complete_phase(person, body)
			else:
				NpcIntentService.move_to(body, DistrictPopulationService.position_for(person.goal_id), intent.arrival_distance)
#endregion
