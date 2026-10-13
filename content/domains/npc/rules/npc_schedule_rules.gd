extends RefCounted
## Pure authored goal and completed-placement calculations; no runtime mutation or scheduling.
class_name NpcScheduleRules


#region Authored schedule calculations
## Chooses the stable goal identity for one authored location and personality.
static func goal_for(
	definition: DEF_District,
	person: NpcRecord,
	location: DEF_NpcSchedule.Location,
	world_seed: int,
	day: int,
	phase: C_DayCycle.Phase,
) -> StringName:
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
	# StringName ordering depends on interned addresses in the pinned engine.
	# Text ordering keeps keyed decisions independent of resource loading/allocation.
	activities.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second),
	)
	var random: RandomNumberGenerator = DecisionRandomRules.generator(
		world_seed,
		String(person.npc_id),
		day,
		"npc/schedule/%d" % phase,
		person.activity_sequence,
	)
	return activities[random.randi_range(0, activities.size() - 1)]


## Accepted evening deliveries keep the recipient outside its own entrance.
static func waiting_at_home(
	district: C_District,
	person: NpcRecord,
	day: int,
	phase: C_DayCycle.Phase,
) -> bool:
	if phase != C_DayCycle.Phase.EVENING:
		return false
	for job: NpcHomeDelivery in district.home_deliveries:
		if (
			job.npc_id == person.npc_id and job.address_id == person.home_id
			and job.day_index == day and job.status == NpcHomeDelivery.Status.ACCEPTED
		):
			return true
	return false


## Resolves the authored location with a durable accepted-delivery obligation.
static func location_for(
	district: C_District,
	person: NpcRecord,
	day: int,
	phase: C_DayCycle.Phase,
) -> DEF_NpcSchedule.Location:
	if waiting_at_home(district, person, day, phase):
		return DEF_NpcSchedule.Location.STREET
	return person.profile.schedule.location_for(day, phase)


## Chooses participation after arriving at the captured authored goal.
static func completed_placement(
	person: NpcRecord,
	waiting_for_delivery: bool = false,
) -> NpcRecord.Placement:
	if waiting_for_delivery:
		return NpcRecord.Placement.STREET
	var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(
		person.planned_day,
		person.planned_phase as C_DayCycle.Phase,
	)
	if location == DEF_NpcSchedule.Location.HOME:
		return NpcRecord.Placement.HOME
	if location == DEF_NpcSchedule.Location.OUTSIDE or not person.profile.resident:
		return NpcRecord.Placement.OUTSIDE
	return NpcRecord.Placement.STREET
#endregion
