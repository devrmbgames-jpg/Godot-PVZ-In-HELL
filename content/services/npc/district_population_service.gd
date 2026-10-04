extends RefCounted
## Постоянное население; временный уход не создаёт другое тело личности.
class_name DistrictPopulationService

static var _lookup_world: World = null
static var _session_reference: WeakRef = null
static var _session_query: QueryBuilder = null

#region Поиск постоянных записей
## Возвращает установленную сессию текущего района.
static func current() -> C_District:
	if not is_instance_valid(ECS.world):
		return null
	if _lookup_world != ECS.world or not is_instance_valid(_lookup_world):
		_lookup_world = ECS.world
		_session_reference = null
		_session_query = QueryBuilder.new(_lookup_world).with_all([C_District])

	var session: Entity = _session_reference.get_ref() as Entity if _session_reference != null else null
	if session != null and _lookup_world.entity_to_archetype.has(session) and session.has_component(C_District):
		return session.get_component(C_District) as C_District

	session = _session_query.execute_one()
	_session_reference = weakref(session) if session != null else null
	return session.get_component(C_District) as C_District if session != null else null

## Находит постоянную личность, включая погибших в истории района.
static func person_for(npc_id: StringName) -> NpcRecord:
	var district: C_District = current()
	if district != null:
		for person: NpcRecord in district.people:
			if person.npc_id == npc_id:
				return person
	return null

## Находит сохранённое тело, в том числе временно отключённое.
static func body_for(npc_id: StringName) -> E_DistrictNpc:
	if not is_instance_valid(ECS.world):
		return null

	var district: C_District = current()
	var reference: WeakRef = district.body_references.get(npc_id) if district != null else null
	var cached: E_DistrictNpc = reference.get_ref() as E_DistrictNpc if reference != null else null
	if cached != null and ECS.world.entities.has(cached):
		var identity: C_NpcIdentity = cached.get_component(C_NpcIdentity) as C_NpcIdentity
		if identity != null and identity.npc_id == npc_id:
			return cached

	for entity: Entity in ECS.world.entities:
		if not is_instance_valid(entity):
			continue

		var identity: C_NpcIdentity = entity.get_component(C_NpcIdentity) as C_NpcIdentity
		if identity != null and identity.npc_id == npc_id:
			if district != null:
				district.body_references[npc_id] = weakref(entity)
			return entity as E_DistrictNpc
	return null

## Возвращает начало координат района независимо от авторских DebugMarkers.
static func origin() -> Node3D:
	return ECS.world.get_parent().get_node_or_null("District") as Node3D if is_instance_valid(ECS.world) else null

## Преобразует авторское место района в мировую позицию.
static func position_for(place_id: StringName) -> Vector3:
	var district: C_District = current()
	var place: DEF_DistrictPlace = district.definition.place_for(place_id) if district != null and district.definition != null else null
	var district_root: Node3D = origin()
	if place != null and not place.anchor_path.is_empty() and is_instance_valid(ECS.world):
		var anchor: Node3D = ECS.world.get_parent().get_node_or_null(place.anchor_path) as Node3D
		if anchor != null:
			var anchored: Vector3 = anchor.global_position
			anchored.y = district_root.global_position.y + place.position.y if district_root != null else place.position.y
			return anchored
	return district_root.to_global(place.position) if place != null and district_root != null else place.position if place != null else Vector3.ZERO

## Возвращает отображаемый адрес, не показывая его внутренний ID.
static func place_name(place_id: StringName) -> String:
	var district: C_District = current()
	var place: DEF_DistrictPlace = district.definition.place_for(place_id) if district != null else null
	return place.display_name if place != null else str(place_id)

## Выбирает текущего живого получателя для нового заказа поставки.
static func recipient_for(recipient_key: StringName) -> NpcRecord:
	var district: C_District = current()
	if district != null:
		for person: NpcRecord in district.people:
			if person.death_day == 0 and person.recipient_key == recipient_key:
				return person
	return null
#endregion

#region Восстановление состояния движка
static func _reset_brain(body: E_DistrictNpc) -> void:
	NpcCommunityService.cancel_activity(body)
	NpcDialogueService.end(body)
	NpcHomeDeliveryService.release_meeting(body)
	CombatService.end_combat(body)
	NpcAttackService.cancel(body)
	NpcIntentService.stop(body)
	if body.has_component(C_CustomerAgent):
		var service: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
		NpcServiceRole.release(body, service.visit_id)
	for script: Script in [C_NpcAwareness, C_NpcDecision, C_NpcRoute]:
		if body.has_component(script):
			body.remove_component(script)

	var runner: BTPlayer = body.get_node_or_null("Brain") as BTPlayer
	if runner != null:
		runner.free()

## Восстанавливает участие в движке и представление личности после снимка.
static func restore_participation() -> void:
	var district: C_District = current()
	if district == null:
		return

	district.noises.clear()
	district.pending_routes.clear()
	district.lighting_context = null
	for person: NpcRecord in district.people:
		var body: E_DistrictNpc = body_for(person.npc_id)
		if body == null:
			continue

		_reset_brain(body)
		_install_roles(body, person)
		body.present_profile(person.profile)
		body.show_message(person.display_name)
		NpcBrainService.install(body)
		body.set_participating(person.placement == NpcRecord.Placement.STREET and person.death_day == 0)
		if person.death_day != 0:
			body.sync_death_presentation()

#endregion

#region Создание населения
## Создаёт одно исходное население до восстановления сохранения при старте.
static func initialize() -> void:
	var district: C_District = current()
	if district == null or district.definition == null or not district.people.is_empty():
		return

	_spawn_addresses()
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
		person.display_name = profile.display_name
		person.recipient_key = profile.recipient_key
		person.portal_id = portals[(district.next_person - 2) % portals.size()]
		person.exit_id = portals[(district.next_person - 1) % portals.size()]
		if profile.resident and home_index < homes.size():
			person.home_id = homes[home_index]
			home_index += 1
		district.people.append(person)
		_spawn_body(person)
	prepare_morning(1)

static func _spawn_addresses() -> void:
	var district: C_District = current()
	var prefab: PackedScene = load("res://content/entities/npc/npc_address.tscn") as PackedScene
	for place: DEF_DistrictPlace in district.definition.places:
		if place.kind != DEF_DistrictPlace.Kind.HOME:
			continue

		var address: Entity = prefab.instantiate() as Entity
		ECS.world.get_parent().add_child(address)
		(address as Node as Node3D).global_position = position_for(place.key)
		ECS.world.add_entity(address, null, false)
		(address.get_component(C_NpcAddress) as C_NpcAddress).address_id = place.key
		(address.get_node("Address") as Label3D).text = place.display_name
	var hud: DistrictDeliveryView = DistrictDeliveryView.new()
	ECS.world.get_parent().add_child(hud)

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
	body.show_message(person.display_name)
	_install_roles(body, person)
	NpcBrainService.install(body)
	body.place_at(position_for(person.home_id if person.profile.resident else person.portal_id))
	return body
#endregion

#region Календарь и участие в мире
## Один раз готовит будущее утро с заселением; повтор записи безопасен.
static func prepare_morning(morning_day: int) -> void:
	var district: C_District = current()
	if district == null or district.prepared_morning >= morning_day:
		return

	district.prepared_morning = morning_day
	district.noises.clear()
	district.pending_routes.clear()
	district.lighting_context = null
	_replace_vacancies(district, morning_day)
	for person: NpcRecord in district.people:
		if person.death_day != 0:
			continue

		var body: E_DistrictNpc = body_for(person.npc_id)
		if body == null:
			continue

		_reset_brain(body)
		NpcBrainService.install(body)
		plan_phase(person, morning_day, C_DayCycle.Phase.MORNING, true)

## Назначает цель фазы; видимый NPC сначала доходит до двери или прохода.
static func plan_phase(person: NpcRecord, day_index: int, phase: C_DayCycle.Phase, synchronize: bool = false) -> void:
	if person.death_day != 0 or (person.planned_day == day_index and person.planned_phase == phase and not synchronize):
		return

	var body: E_DistrictNpc = body_for(person.npc_id)
	if body == null:
		return

	person.planned_day = day_index
	person.planned_phase = phase
	person.phase_complete = false
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	if awareness != null:
		awareness.called_out = false
		awareness.warned_rules.clear()
		awareness.reacted_rules.clear()
		awareness.rule_exposure.clear()

	var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(day_index, phase)
	person.goal_id = person.home_id if location == DEF_NpcSchedule.Location.HOME else person.portal_id if location == DEF_NpcSchedule.Location.OUTSIDE else _activity_for(person) if person.profile.resident else person.exit_id
	if synchronize:
		body.place_at(position_for(person.home_id if person.profile.resident else person.portal_id))
		set_placement(person, body, NpcRecord.Placement.STREET if location == DEF_NpcSchedule.Location.STREET else NpcRecord.Placement.HOME if location == DEF_NpcSchedule.Location.HOME else NpcRecord.Placement.OUTSIDE)
	elif location == DEF_NpcSchedule.Location.STREET and person.placement != NpcRecord.Placement.STREET:
		body.place_at(position_for(person.home_id if person.placement == NpcRecord.Placement.HOME else person.portal_id))
		set_placement(person, body, NpcRecord.Placement.STREET)

## Изменяет авторитетное размещение и участие тела в движке.
static func set_placement(person: NpcRecord, body: E_DistrictNpc, placement: NpcRecord.Placement) -> void:
	person.placement = placement
	var active: bool = placement == NpcRecord.Placement.STREET
	if active and not body.enabled:
		ECS.world.enable_entity(body)
	elif not active and body.enabled:
		NpcCommunityService.cancel_activity(body)
		NpcDialogueService.end(body)
		NpcIntentService.stop(body)
		CombatService.end_combat(body)
		ECS.world.disable_entity(body)
	body.set_participating(active)
	if placement == NpcRecord.Placement.DEAD:
		body.sync_death_presentation()

## Завершает обязательную цель фазы после прибытия.
static func complete_phase(person: NpcRecord, body: E_DistrictNpc) -> void:
	person.phase_complete = true
	var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(person.planned_day, person.planned_phase as C_DayCycle.Phase)
	if not person.profile.resident and location == DEF_NpcSchedule.Location.STREET:
		set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	elif location != DEF_NpcSchedule.Location.STREET:
		set_placement(person, body, NpcRecord.Placement.HOME if location == DEF_NpcSchedule.Location.HOME else NpcRecord.Placement.OUTSIDE)

## Один раз фиксирует смерть; будущие заказы не используют погибшую личность.
static func mark_dead(person: NpcRecord, body: E_DistrictNpc, day_index: int) -> void:
	if person.death_day != 0:
		return

	NpcRemainsService.release(body)
	NpcServiceRole.mark_dead(person, body, day_index)
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
	var pool: Array[DEF_NpcProfile] = []
	var initiators: int = 0
	for person: NpcRecord in district.people:
		if person.death_day == 0 and person.profile.resident and person.profile.initiates_conflicts:
			initiators += 1
	for candidate: DEF_NpcProfile in district.definition.profiles:
		if candidate.resident == deceased.profile.resident and candidate.merchant == deceased.profile.merchant and candidate.valid_rules() and (not candidate.initiates_conflicts or initiators < district.definition.maximum_conflict_initiators):
			pool.append(candidate)
	replacement.profile = pool[abs(hash(replacement.npc_id)) % pool.size()] if not pool.is_empty() else deceased.profile

	var names: PackedStringArray = district.definition.replacement_names
	replacement.display_name = "%s %d" % [names[(district.next_person - 2) % names.size()] if not names.is_empty() else replacement.profile.display_name, district.next_person - 1]
	replacement.recipient_key = deceased.recipient_key
	replacement.home_id = deceased.home_id
	replacement.portal_id = deceased.portal_id
	replacement.exit_id = deceased.exit_id
	deceased.home_id = &""
	deceased.portal_id = &""
	district.people.append(replacement)
	_spawn_body(replacement)

static func _install_roles(body: E_DistrictNpc, person: NpcRecord) -> void:
	if not body.has_component(C_Inventory):
		body.add_component(C_Inventory.new())
	if not body.has_component(C_Hunger):
		var hunger: C_Hunger = C_Hunger.new()
		hunger.policy = load("res://content/definitions/gameplay/hunger/def_hunger_default.tres") as DEF_HungerPolicy
		hunger.value = current().definition.npc_start_hunger
		body.add_component(hunger)

	var actions: C_InteractionActionSet = body.get_component(C_InteractionActionSet) as C_InteractionActionSet
	if actions == null:
		actions = C_InteractionActionSet.new()
		body.add_component(actions)
	var street: DEF_NpcDialogueAction = DEF_NpcDialogueAction.new()
	street.action_id = &"npc_street_dialogue"
	street.caption = "Поговорить с жителем"
	street.slot = DEF_InteractionAction.Slot.INTERACT
	street.priority = 5
	if not actions.actions.any(func(action: DEF_InteractionAction) -> bool: return action.action_id == street.action_id):
		actions.actions.append(street)
	if person.profile.merchant and not body.has_component(C_Trader):
		var trader: C_Trader = C_Trader.new()
		trader.profile = load("res://content/definitions/gameplay/commerce/def_trader_default.tres") as DEF_TraderProfile
		body.add_component(trader)
		var trade: DEF_TraderAction = DEF_TraderAction.new()
		trade.action_id = &"trade"
		trade.caption = "Торговля и задание"
		actions.actions.append(trade)
		var pickup: Marker3D = Marker3D.new()
		pickup.name = "FurniturePickup"
		pickup.position = Vector3(2, 0, 0)
		body.add_child(pickup)
#endregion
