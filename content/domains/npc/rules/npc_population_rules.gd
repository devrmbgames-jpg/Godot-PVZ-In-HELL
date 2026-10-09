extends RefCounted
## Pure initial roster allocation; records are detached until the district construction commits.
class_name NpcPopulationRules


#region Initial roster
## Preserves authored Profile order, sequential identity, homes and paired entry/exit portals.
static func initial_records(definition: DEF_District, next_person: int) -> Array[NpcRecord]:
	var people: Array[NpcRecord] = []
	if definition == null:
		return people
	var homes: Array[StringName] = []
	var portals: Array[StringName] = []
	for place: DEF_DistrictPlace in definition.places:
		if place.kind == DEF_DistrictPlace.Kind.HOME:
			homes.append(place.key)
		elif place.kind == DEF_DistrictPlace.Kind.PORTAL:
			portals.append(place.key)

	var home_index: int = 0
	for profile: DEF_NpcProfile in definition.profiles:
		if profile == null or not profile.valid_rules() or portals.is_empty():
			continue
		var person_number: int = next_person + people.size()
		var person: NpcRecord = NpcRecord.new()
		person.npc_id = StringName("npc/%d" % person_number)
		person.profile = profile
		person.display_name = profile.display_name
		person.recipient_key = profile.recipient_key
		person.portal_id = portals[(person_number - 1) % portals.size()]
		person.exit_id = portals[person_number % portals.size()]
		if profile.resident and home_index < homes.size():
			person.home_id = homes[home_index]
			home_index += 1
		people.append(person)
	return people
#endregion
