extends RefCounted
## Permanent population lifecycle; temporary departures never instantiate another person.
class_name DistrictPopulationService

#region Lookups
## Returns the scene-local district session, if installed.
static func current() -> C_District:
	if not is_instance_valid(ECS.world):
		return null
	var session: Entity = ECS.world.query.with_all([C_District]).execute_one()
	return session.get_component(C_District) as C_District if session != null else null

## Looks up permanent identity, including historical dead people.
static func person_for(npc_id: StringName) -> NpcRecord:
	var district: C_District = current()
	if district != null:
		for person: NpcRecord in district.people:
			if person.npc_id == npc_id:
				return person
	return null

## Finds a retained body, including temporarily disabled bodies.
static func body_for(npc_id: StringName) -> E_DistrictNpc:
	if not is_instance_valid(ECS.world):
		return null
	for entity: Entity in ECS.world.entities:
		if not is_instance_valid(entity):
			continue
		var identity: C_NpcIdentity = entity.get_component(C_NpcIdentity) as C_NpcIdentity
		if identity != null and identity.npc_id == npc_id:
			return entity as E_DistrictNpc
	return null

## Gets the district origin independently of authored debug markers.
static func origin() -> Node3D:
	return ECS.world.get_parent().get_node_or_null("District") as Node3D if is_instance_valid(ECS.world) else null

## Resolves a district place to its world position.
static func position_for(place_id: StringName) -> Vector3:
	var district: C_District = current()
	var place: DEF_DistrictPlace = district.definition.place_for(place_id) if district != null and district.definition != null else null
	var district_root: Node3D = origin()
	return district_root.to_global(place.position) if place != null and district_root != null else place.position if place != null else Vector3.ZERO

## Selects the current living recipient for a newly created parcel case.
static func recipient_for(recipient_key: StringName) -> NpcRecord:
	var district: C_District = current()
	if district != null:
		for person: NpcRecord in district.people:
			if person.death_day == 0 and person.profile.recipient_key == recipient_key:
				return person
	return null
#endregion

#region Native restoration
## Restores native participation and readable identity after a snapshot.
static func restore_participation() -> void:
	var district: C_District = current()
	if district == null:
		return
	for person: NpcRecord in district.people:
		var body: E_DistrictNpc = body_for(person.npc_id)
		if body == null:
			continue
		body.present_profile(person.profile)
		NpcBrainService.install(body)
		body.set_participating(person.placement == NpcRecord.Placement.STREET and person.death_day == 0)
		if person.death_day != 0:
			body.sync_death_presentation()

#endregion

#region Population initialization
## Seeds exactly one initial population before startup save restoration.
static func initialize() -> void:
	var district: C_District = current()
	if district == null or district.definition == null or not district.people.is_empty():
		return
	for light_node: Node in ECS.world.get_parent().find_children("*", "Light3D", true, false):
		district.light_sources.append(light_node as Light3D)
	var homes: Array[StringName] = []
	var portals: Array[StringName] = []
	for place: DEF_DistrictPlace in district.definition.places:
		if place.kind == DEF_DistrictPlace.Kind.HOME:
			homes.append(place.key)
		elif place.kind == DEF_DistrictPlace.Kind.PORTAL:
			portals.append(place.key)
	var home_index: int = 0
	for profile: DEF_NpcProfile in district.definition.profiles:
		if profile == null or not profile.valid_rules() or portals.is_empty():
			continue
		var person: NpcRecord = NpcRecord.new()
		person.npc_id = StringName("npc/%d" % district.next_person)
		district.next_person += 1
		person.profile = profile
		person.portal_id = portals[(district.next_person - 2) % portals.size()]
		if profile.resident and home_index < homes.size():
			person.home_id = homes[home_index]
			home_index += 1
		district.people.append(person)
		_spawn_body(person)
	prepare_morning(1)

static func _spawn_body(person: NpcRecord) -> E_DistrictNpc:
	var scene: PackedScene = load(person.profile.npc_scene_path) as PackedScene
	if scene == null:
		return null
	var body: E_DistrictNpc = ECS.world.get_parent().get_node_or_null("Entityes/Trader") as E_DistrictNpc if person.profile.merchant else null
	if body == null or body.has_component(C_NpcIdentity):
		body = scene.instantiate() as E_DistrictNpc
		if body == null:
			return null
		ECS.world.get_parent().add_child(body)
		ECS.world.add_entity(body, null, false)
	var identity: C_NpcIdentity = C_NpcIdentity.new()
	body.add_component(identity)
	identity.npc_id = person.npc_id
	var persistent: C_PersistentIdentity = C_PersistentIdentity.new()
	persistent.key = String(person.npc_id)
	body.add_component(persistent)
	if body.has_component(C_CustomerAgent):
		body.remove_component(C_CustomerAgent)
	var motion: C_Motion = body.get_component(C_Motion) as C_Motion
	motion.max_speed = person.profile.move_speed
	body.present_profile(person.profile)
	NpcBrainService.install(body)
	body.place_at(position_for(person.home_id if person.profile.resident else person.portal_id))
	return body
#endregion

#region Calendar and participation
## Prepares a future morning once, including replacement; safe for repeated save attempts.
static func prepare_morning(morning_day: int) -> void:
	var district: C_District = current()
	if district == null or district.prepared_morning >= morning_day:
		return
	district.prepared_morning = morning_day
	_replace_vacancies(district, morning_day)
	for person: NpcRecord in district.people:
		if person.death_day != 0:
			continue
		var body: E_DistrictNpc = body_for(person.npc_id)
		if body == null:
			continue
		plan_phase(person, morning_day, C_DayCycle.Phase.MORNING, true)

## Assigns a phase destination; visible departures move to a door or portal first.
static func plan_phase(person: NpcRecord, day_index: int, phase: C_DayCycle.Phase, synchronize: bool = false) -> void:
	if person.death_day != 0 or (person.planned_day == day_index and person.planned_phase == phase and not synchronize):
		return
	var body: E_DistrictNpc = body_for(person.npc_id)
	if body == null:
		return
	person.planned_day = day_index
	person.planned_phase = phase
	person.phase_complete = false
	var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(day_index, phase)
	person.goal_id = person.home_id if location == DEF_NpcSchedule.Location.HOME else person.portal_id if location == DEF_NpcSchedule.Location.OUTSIDE else _activity_for(person)
	if synchronize:
		body.place_at(position_for(person.home_id if person.profile.resident else person.portal_id))
		set_placement(person, body, NpcRecord.Placement.STREET if location == DEF_NpcSchedule.Location.STREET else NpcRecord.Placement.HOME if location == DEF_NpcSchedule.Location.HOME else NpcRecord.Placement.OUTSIDE)
	elif location == DEF_NpcSchedule.Location.STREET and person.placement != NpcRecord.Placement.STREET:
		body.place_at(position_for(person.home_id if person.placement == NpcRecord.Placement.HOME else person.portal_id))
		set_placement(person, body, NpcRecord.Placement.STREET)

## Authoritative placement transition with native engine participation.
static func set_placement(person: NpcRecord, body: E_DistrictNpc, placement: NpcRecord.Placement) -> void:
	person.placement = placement
	var active: bool = placement == NpcRecord.Placement.STREET
	if active and not body.enabled:
		ECS.world.enable_entity(body)
	elif not active and body.enabled:
		NpcIntentService.stop(body)
		CombatService.end_combat(body)
		ECS.world.disable_entity(body)
	body.set_participating(active)
	if placement == NpcRecord.Placement.DEAD:
		body.sync_death_presentation()

## Completes a phase anchor after reaching its destination.
static func complete_phase(person: NpcRecord, body: E_DistrictNpc) -> void:
	person.phase_complete = true
	var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(person.planned_day, person.planned_phase as C_DayCycle.Phase)
	if location != DEF_NpcSchedule.Location.STREET:
		set_placement(person, body, NpcRecord.Placement.HOME if location == DEF_NpcSchedule.Location.HOME else NpcRecord.Placement.OUTSIDE)

## Records terminal death once; future cases cannot reuse the deceased person.
static func mark_dead(person: NpcRecord, body: E_DistrictNpc, day_index: int) -> void:
	if person.death_day != 0:
		return
	person.death_day = day_index
	person.phase_complete = true
	set_placement(person, body, NpcRecord.Placement.DEAD)
	var district: C_District = current()
	var living_residents: int = 0
	for other: NpcRecord in district.people:
		if other.profile.resident and other.death_day == 0:
			living_residents += 1
	if district.replacement_morning == 0 and district.definition.resident_count - living_residents >= district.definition.replacement_threshold:
		district.replacement_morning = day_index + district.definition.replacement_delay_days

static func _activity_for(person: NpcRecord) -> StringName:
	var district: C_District = current()
	if person.profile.merchant:
		for place: DEF_DistrictPlace in district.definition.places:
			if place.kind == DEF_DistrictPlace.Kind.SHOP:
				return place.key
	var activities: Array[StringName] = []
	for place: DEF_DistrictPlace in district.definition.places:
		if place.kind == DEF_DistrictPlace.Kind.ACTIVITY:
			activities.append(place.key)
	return activities[abs(hash(person.npc_id) + person.activity_sequence) % activities.size()] if not activities.is_empty() else person.portal_id

static func _replace_vacancies(district: C_District, morning_day: int) -> void:
	var locals_alive: int = 0
	var outside_alive: int = 0
	var vacant: NpcRecord = null
	for person: NpcRecord in district.people:
		if person.death_day == 0:
			if person.profile.resident: locals_alive += 1
			else: outside_alive += 1
		elif person.profile.resident and not person.home_id.is_empty():
			if vacant == null or person.profile.merchant:
				vacant = person
	if district.replacement_morning > 0 and morning_day >= district.replacement_morning and locals_alive < district.definition.resident_count and vacant != null:
		_replace_person(district, vacant)
		locals_alive += 1
		district.replacement_morning = morning_day + 1 if locals_alive < district.definition.resident_count else 0
	if outside_alive < district.definition.visitor_count:
		for person: NpcRecord in district.people:
			if not person.profile.resident and person.death_day > 0 and morning_day >= person.death_day + district.definition.replacement_delay_days and not person.portal_id.is_empty():
				_replace_person(district, person)
				break

static func _replace_person(district: C_District, deceased: NpcRecord) -> void:
	var replacement: NpcRecord = NpcRecord.new()
	replacement.npc_id = StringName("npc/%d" % district.next_person)
	district.next_person += 1
	replacement.profile = deceased.profile
	replacement.home_id = deceased.home_id
	replacement.portal_id = deceased.portal_id
	deceased.home_id = &""
	deceased.portal_id = &""
	district.people.append(replacement)
	_spawn_body(replacement)
#endregion
