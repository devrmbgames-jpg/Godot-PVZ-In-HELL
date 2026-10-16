extends RefCounted
## Pure initial roster allocation; records are detached until the district construction commits.
class_name NpcPopulationRules


#region Initial roster
## Preserves authored Profile order, sequential identity, homes and paired entry/exit portals.
static func initial_records(
	definition: DEF_District,
	next_person: int,
	world_seed: int,
	creation_day: int = 1,
) -> Array[NpcRecord]:
	var people: Array[NpcRecord] = []
	if definition == null or next_person < 1 or creation_day < 1:
		return people
	if not definition.authored_people.is_empty():
		return NpcAuthoredPersonRules.initial_records(definition.authored_people, definition)
	var homes: Array[StringName] = []
	var portals: Array[StringName] = []
	for place: DEF_DistrictPlace in definition.places:
		if place.kind == DEF_DistrictPlace.Kind.HOME:
			homes.append(place.key)
		elif place.kind == DEF_DistrictPlace.Kind.PORTAL:
			portals.append(place.key)

	var home_index: int = 0
	for profile: DEF_NpcArchetype in definition.profiles:
		if profile == null or not profile.valid_rules() or portals.is_empty():
			continue
		var person_number: int = next_person + people.size()
		var person: NpcRecord = NpcRecord.new()
		person.npc_id = StringName("npc/%d" % person_number)
		person.profile = profile
		person.variation = NpcVariationRules.create(
			profile,
			world_seed,
			person.npc_id,
			creation_day,
		)
		person.recipient_key = profile.recipient_key
		person.portal_id = portals[(person_number - 1) % portals.size()]
		person.exit_id = portals[person_number % portals.size()]
		if profile.resident and home_index < homes.size():
			person.home_id = homes[home_index]
			home_index += 1
		people.append(person)
	return people


## Резервирует только свободные числовые ID; авторские номера не обязаны быть последовательными.
static func next_person_after(people: Array[NpcRecord], first_available: int) -> int:
	var next_person: int = first_available
	for person: NpcRecord in people:
		next_person = maxi(next_person, String(person.npc_id).trim_prefix("npc/").to_int() + 1)
	return next_person
#endregion
