extends RefCounted
## Closed district snapshot validation before mutating bodies, ownership or calendar state.
class_name DistrictSnapshotRules

#region Persistent district validation
## Checks stable identities, placements, addresses, profiles, memory and evening promises.
static func valid(records: Dictionary[String, Dictionary], components: Dictionary[String, Dictionary], morning_day: int) -> bool:
	var district: C_District = null
	var flow: C_CustomerFlow = null
	var identities: Dictionary[StringName, String] = {}
	for key: String in components:
		var fields: Dictionary = components[key]
		if fields.has(C_District):
			if district != null:
				return false
			district = fields[C_District] as C_District
		if fields.has(C_CustomerFlow):
			flow = fields[C_CustomerFlow] as C_CustomerFlow
		if fields.has(C_NpcIdentity):
			var identity: C_NpcIdentity = fields[C_NpcIdentity] as C_NpcIdentity
			if identity.npc_id.is_empty() or identities.has(identity.npc_id) or key != String(identity.npc_id):
				return false
			identities[identity.npc_id] = key
	if district == null:
		return identities.is_empty()
	if district.definition == null or district.prepared_morning > morning_day or district.prepared_morning < 0 or district.next_incident < 1 or district.next_service_order < 1:
		return false
	var people: Dictionary[StringName, NpcRecord] = {}
	var occupied: Dictionary[StringName, bool] = {}
	var aliases: Dictionary[StringName, bool] = {}
	var locals: int = 0
	var visitors: int = 0
	var sequence: int = 0
	for person: NpcRecord in district.people:
		if person == null or person.npc_id.is_empty() or people.has(person.npc_id) or person.profile == null or not district.definition.profiles.has(person.profile) or not person.profile.valid_rules() or person.display_name.is_empty():
			return false
		if not String(person.npc_id).begins_with("npc/") or not String(person.npc_id).get_slice("/", 1).is_valid_int():
			return false
		sequence = maxi(sequence, int(String(person.npc_id).get_slice("/", 1)))
		people[person.npc_id] = person
		if person.death_day < 0 or person.death_day > morning_day or person.placement < NpcRecord.Placement.STREET or person.placement > NpcRecord.Placement.DEAD or (person.death_day > 0) != (person.placement == NpcRecord.Placement.DEAD):
			return false
		if person.planned_day > morning_day or person.planned_day < 0 or person.planned_phase < -1 or person.planned_phase > C_DayCycle.Phase.NIGHT:
			return false
		if person.death_day == 0:
			if not identities.has(person.npc_id):
				return false
			var body_record: Dictionary = records[identities[person.npc_id]]
			if bool(body_record.death) or bool(body_record.enabled) != (person.placement == NpcRecord.Placement.STREET):
				return false
			if person.profile.resident:
				locals += 1
				var address: DEF_DistrictPlace = district.definition.place_for(person.home_id)
				if address == null or address.kind != DEF_DistrictPlace.Kind.HOME or occupied.has(person.home_id):
					return false
				occupied[person.home_id] = true
			else:
				visitors += 1
			if not person.recipient_key.is_empty():
				if aliases.has(person.recipient_key):
					return false
				aliases[person.recipient_key] = true
			var portal: DEF_DistrictPlace = district.definition.place_for(person.portal_id)
			if portal == null or portal.kind != DEF_DistrictPlace.Kind.PORTAL:
				return false
			var exit_place: DEF_DistrictPlace = district.definition.place_for(person.exit_id)
			if exit_place == null or exit_place.kind != DEF_DistrictPlace.Kind.PORTAL:
				return false
		var incidents: Dictionary[StringName, bool] = {}
		for memory: NpcMemory in person.memories:
			if memory == null or memory.incident_id.is_empty() or incidents.has(memory.incident_id) or memory.kind < NpcMemory.Kind.HELP or memory.kind > NpcMemory.Kind.OFFENSE or memory.reaction < NpcMemory.Reaction.TALK or memory.reaction > NpcMemory.Reaction.RESPECT or memory.day < 1 or memory.day > morning_day:
				return false
			incidents[memory.incident_id] = true
	if district.next_person <= sequence or locals > district.definition.resident_count or visitors > district.definition.visitor_count:
		return false
	for identity: StringName in identities:
		if not people.has(identity):
			return false
	var jobs: Dictionary[StringName, bool] = {}
	var counts: Dictionary[int, int] = {}
	for job: NpcHomeDelivery in district.home_deliveries:
		if job == null or job.job_id.is_empty() or jobs.has(job.job_id) or not people.has(job.npc_id) or job.order_number < 1 or job.day_index < 1 or job.day_index > morning_day or job.status < NpcHomeDelivery.Status.ACCEPTED or job.status > NpcHomeDelivery.Status.FAILED:
			return false
		jobs[job.job_id] = true
		counts[job.day_index] = counts.get(job.day_index, 0) + 1
		if counts[job.day_index] > district.definition.maximum_home_deliveries or (job.bonus_committed and job.status != NpcHomeDelivery.Status.DELIVERED):
			return false
		var address: DEF_DistrictPlace = district.definition.place_for(job.address_id)
		if address == null or address.kind != DEF_DistrictPlace.Kind.HOME or flow == null:
			return false
		var matching: bool = false
		for visit: CustomerVisit in flow.visits:
			if visit.visit_id == job.visit_id and visit.customer_id == job.npc_id:
				matching = true
		if not matching:
			return false
	return true
#endregion
