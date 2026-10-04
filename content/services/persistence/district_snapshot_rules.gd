extends RefCounted
## Проверяет закрытый снимок района до изменения тел, владения и календаря.
class_name DistrictSnapshotRules

#region Проверка постоянного района
## Проверяет личности, размещение, адреса, профили, память и вечерние обязательства.
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

	return _deliveries_valid(district, flow, people, morning_day)
#endregion

#region Предложения и обязательства
static func _deliveries_valid(district: C_District, flow: C_CustomerFlow, people: Dictionary[StringName, NpcRecord], morning_day: int) -> bool:
	if district.delivery_offer_day < 0 or district.delivery_offer_day > morning_day or district.terminal_offer_target < 0 or district.terminal_offer_target > 3:
		return false
	if district.delivery_offer_day == 0 and (district.terminal_offer_target != 0 or not district.delivery_considered.is_empty()):
		return false
	var visits: Dictionary[StringName, CustomerVisit] = {}
	if flow != null:
		for visit: CustomerVisit in flow.visits:
			visits[visit.visit_id] = visit
	var considered: Dictionary[String, bool] = {}
	for visit_id: String in district.delivery_considered:
		if considered.has(visit_id) or not visits.has(StringName(visit_id)):
			return false
		considered[visit_id] = true
	var jobs: Dictionary[StringName, bool] = {}
	var parcels: Dictionary[String, bool] = {}
	for job: NpcHomeDelivery in district.home_deliveries:
		if job == null or job.job_id.is_empty() or jobs.has(job.job_id) or job.package_id.is_empty() or parcels.has(job.package_id) or not people.has(job.npc_id):
			return false
		jobs[job.job_id] = true
		parcels[job.package_id] = true
		if job.order_number < 1 or job.day_index < 1 or job.day_index > morning_day or job.deadline_day != job.day_index + 1:
			return false
		if job.status < NpcHomeDelivery.Status.ACCEPTED or job.status > NpcHomeDelivery.Status.EXPIRED or job.source < NpcHomeDelivery.Source.TERMINAL or job.source > NpcHomeDelivery.Source.PERSONAL:
			return false
		if job.base_bonus < 0 or job.bonus < 0 or job.bonus > WalletService.MAX_AMOUNT or not is_finite(job.bargain_roll) or job.bargain_roll < 0.0 or job.bargain_roll >= 1.0:
			return false
		if job.bargain < NpcHomeDelivery.Bargain.NONE or job.bargain > NpcHomeDelivery.Bargain.DECLINED or (job.bonus_committed and job.status != NpcHomeDelivery.Status.DELIVERED):
			return false
		if job.source == NpcHomeDelivery.Source.TERMINAL and (not job.published or job.bargain != NpcHomeDelivery.Bargain.NONE):
			return false
		if (job.bargain != NpcHomeDelivery.Bargain.ACCEPTED and job.bonus != job.base_bonus) or job.bonus < job.base_bonus:
			return false
		if not job.package_history_id.is_empty() and PackageHistoryId.parse(job.package_history_id) == null:
			return false
		var address: DEF_DistrictPlace = district.definition.place_for(job.address_id)
		var person: NpcRecord = people[job.npc_id]
		if address == null or address.kind != DEF_DistrictPlace.Kind.HOME or not person.profile.resident or person.home_id != job.address_id:
			return false
		var visit: CustomerVisit = visits.get(job.visit_id) as CustomerVisit
		if visit == null or visit.customer_id != job.npc_id or visit.package_id != job.package_id:
			return false
	return true
#endregion
