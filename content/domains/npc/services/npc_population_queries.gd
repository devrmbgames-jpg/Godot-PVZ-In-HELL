extends RefCounted
## Читает записи населения и находит их зарегистрированные физические тела.
class_name NpcPopulationQueries

static var _lookup_world: World = null
static var _session_reference: WeakRef = null
static var _session_query: QueryBuilder = null

#region Чтение состояния
## Возвращает установленную сессию текущего района.
static func current() -> C_District:
	if not is_instance_valid(ECS.world):
		return null
	if _lookup_world != ECS.world or not is_instance_valid(_lookup_world):
		# Static query recipes retain Component scripts; release them at world handoff/exit.
		if not ECS.world_changed.is_connected(_clear_lookup):
			ECS.world_changed.connect(_clear_lookup)
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

#region Query cache lifetime
static func _clear_lookup(_next_world: World) -> void:
	# The callback belongs to this cache lifetime, not the lifetime of the ECS autoload.
	ECS.world_changed.disconnect(_clear_lookup)
	_lookup_world = null
	_session_query = null
	_session_reference = null
#endregion
