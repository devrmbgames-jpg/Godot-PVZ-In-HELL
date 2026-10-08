extends RefCounted
## Pure authored goal and completed-placement calculations; no runtime mutation or scheduling.
class_name NpcScheduleRules

#region Authored schedule calculations
## Chooses the stable goal identity for one authored location and personality.
static func goal_for(definition: DEF_District, person: NpcRecord, location: DEF_NpcSchedule.Location) -> StringName:
	if location == DEF_NpcSchedule.Location.HOME:
		return person.home_id
	if location == DEF_NpcSchedule.Location.OUTSIDE:
		return person.portal_id
	if not person.profile.resident:
		return person.exit_id

	if person.profile.merchant:
		for place: DEF_DistrictPlace in definition.places:
			if place.kind == DEF_DistrictPlace.Kind.SHOP:
				return place.key

	var activities: Array[StringName] = []
	for place: DEF_DistrictPlace in definition.places:
		if place.kind == DEF_DistrictPlace.Kind.ACTIVITY:
			activities.append(place.key)
	if activities.is_empty():
		return person.portal_id
	return activities[abs(hash(person.npc_id) + person.activity_sequence) % activities.size()]


## Chooses participation after arriving at the captured authored goal.
static func completed_placement(person: NpcRecord) -> NpcRecord.Placement:
	var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(
		person.planned_day, person.planned_phase as C_DayCycle.Phase
	)
	if location == DEF_NpcSchedule.Location.HOME:
		return NpcRecord.Placement.HOME
	if location == DEF_NpcSchedule.Location.OUTSIDE or not person.profile.resident:
		return NpcRecord.Placement.OUTSIDE
	return NpcRecord.Placement.STREET
#endregion
