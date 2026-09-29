extends RefCounted
## Domain-safe Package mutations used only by developer-console commands.
class_name DebugPackageService

const MAX_SPAWN_COUNT: int = 50
const MODE_RECEIVING: String = "receiving"
const MODE_SELF: String = "self"
const SELF_FORWARD_DISTANCE: float = 2.0
const SELF_VERTICAL_OFFSET: float = 0.6
const SELF_SIDE_SPACING: float = 1.2
const SELF_ROW_SPACING: float = 1.2
const SELF_COLUMNS: int = 3
const DEBUG_ID_PREFIX: String = "debug:"


static func spawn(
	definition_key: StringName,
	count: int,
	mode: String,
	register_packages: bool,
) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if count < 1 or count > MAX_SPAWN_COUNT:
		result.message = "count must be between 1 and %d" % MAX_SPAWN_COUNT
		return result
	if mode != MODE_RECEIVING and mode != MODE_SELF:
		result.message = "mode must be receiving or self"
		return result
	if not is_instance_valid(ECS.world):
		result.message = "ECS world is unavailable"
		return result

	var zone: E_ReceivingZone = _receiving_zone()
	if zone == null or zone.supply == null:
		result.message = "receiving zone/supply is unavailable"
		return result
	var definition: DEF_Package = _definition(zone, definition_key)
	if definition == null:
		result.message = "package definition was not found: %s" % String(definition_key)
		return result
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null:
		result.message = "day cycle is unavailable"
		return result

	var spawned: Array[Entity] = []
	for package_index: int in count:
		var package_id: String = _next_package_id(
			zone.supply.key,
			cycle.day_index,
			definition.key,
		)
		var parcel: E_Package = ReceivingPackageFactory.create(
			zone,
			definition,
			package_id,
			cycle.day_index,
			package_index,
		)
		if parcel == null:
			_rollback(spawned)
			result.message = "failed to construct package scene"
			return result

		var placed: bool = (
			ReceivingPackageFactory.try_place(zone, parcel)
			if mode == MODE_RECEIVING
			else _place_near_player(zone, parcel, package_index)
		)
		if not placed:
			if not parcel.is_inside_tree():
				parcel.free()
			_rollback(spawned)
			result.message = "failed to place package"
			return result

		spawned.append(parcel)
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		if identity == null:
			_rollback(spawned)
			result.message = "spawned package has no identity"
			return result
		identity.delivery_day = cycle.day_index
		identity.supply_key = zone.supply.key
		if PackageHistoryService.ensure_history_id(parcel, cycle.day_index).is_empty():
			_rollback(spawned)
			result.message = "failed to allocate package history ID"
			return result

		var number_text: String = "unregistered"
		if register_packages:
			var registration: PackageScanResult = PackageRegistrationService.register_package(parcel)
			if (
				registration.outcome != PackageScanResult.Outcome.REGISTERED
				and registration.outcome != PackageScanResult.Outcome.ALREADY_REGISTERED
			):
				_rollback(spawned)
				result.message = "package registration failed"
				return result
			number_text = "#%03d" % registration.number
		result.details.append(
			"package_id=%s definition=%s number=%s"
			% [package_id, String(definition.key), number_text]
		)

	result.success = true
	result.message = "spawned=%d mode=%s" % [spawned.size(), mode]
	return result


static func remove(target: DebugTarget) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if target.kind != DebugTarget.Kind.PACKAGE:
		result.message = target.error if not target.error.is_empty() else "target is not a package"
		return result
	if not EntityAvailability.contains(target.entity, ECS.world):
		result.message = "package is not live"
		return result
	var package_id: String = target.package_id
	_remove_live_package(target.entity)
	result.success = true
	result.message = "removed physical package"
	result.details.append("package_id=%s" % package_id)
	return result


static func purge(target: DebugTarget) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if target.kind != DebugTarget.Kind.PACKAGE:
		result.message = target.error if not target.error.is_empty() else "target is not a package"
		return result
	if not target.package_id.begins_with(DEBUG_ID_PREFIX):
		result.message = "purge is limited to debug-created package ids"
		return result
	if (
		target.visit != null
		and (target.visit.settlement_committed or target.visit.complaint != null)
	):
		result.message = "cannot purge package with committed settlement/complaint history"
		return result

	if EntityAvailability.contains(target.entity, ECS.world):
		_remove_live_package(target.entity)
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger != null:
		for record: PackageRegistrationRecord in ledger.records.duplicate():
			if record.package_id == target.package_id:
				ledger.records.erase(record)
	var flow: C_CustomerFlow = CustomerFlowService.current()
	if flow != null:
		for visit: CustomerVisit in flow.visits.duplicate():
			if visit.package_id == target.package_id:
				flow.visits.erase(visit)

	result.success = true
	result.message = "purged debug package state"
	result.details.append("package_id=%s" % target.package_id)
	return result


static func register(target: DebugTarget) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if target.kind != DebugTarget.Kind.PACKAGE:
		result.message = target.error if not target.error.is_empty() else "target is not a package"
		return result
	if not EntityAvailability.contains(target.entity, ECS.world):
		result.message = "package is not live"
		return result
	var registration: PackageScanResult = PackageRegistrationService.register_package(target.entity)
	if registration.outcome == PackageScanResult.Outcome.REJECTED:
		result.message = registration.message
		return result
	result.success = true
	result.message = registration.message
	result.details.append("package_id=%s" % registration.package_id)
	result.details.append("number=#%03d" % registration.number)
	return result


static func reset(target: DebugTarget) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if target.kind != DebugTarget.Kind.PACKAGE:
		result.message = target.error if not target.error.is_empty() else "target is not a package"
		return result
	if not EntityAvailability.contains(target.entity, ECS.world):
		result.message = "package is not live; destroyed packages must be respawned"
		return result

	var health: C_Health = target.entity.get_component(C_Health) as C_Health
	var state: C_PackageState = target.entity.get_component(C_PackageState) as C_PackageState
	if health == null or state == null:
		result.message = "package Health/state is unavailable"
		return result
	if health.depleted or state.damage == C_PackageState.Damage.DESTROYED:
		result.message = "destroyed package must be respawned"
		return result
	if not is_finite(health.value) or health.value <= 0.0:
		result.message = "package maximum Health is invalid"
		return result

	var previous_health: float = health.current
	var previous_damage: C_PackageState.Damage = state.damage
	health.current = health.value
	health.depleted = false
	state.damage = C_PackageState.Damage.UNDAMAGED
	state.leaking = false

	result.success = true
	result.message = "package reset"
	result.details.append(
		"hp=%.1f -> %.1f" % [previous_health, health.current]
	)
	result.details.append(
		"damage=%s -> UNDAMAGED"
		% String(C_PackageState.Damage.keys()[previous_damage])
	)
	result.details.append("leaking=false")
	return result


static func definition_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	var zone: E_ReceivingZone = _receiving_zone()
	if zone == null or zone.supply == null:
		return keys
	for definition: DEF_Package in zone.supply.packages:
		keys.append(String(definition.key))
	return keys


static func _receiving_zone() -> E_ReceivingZone:
	if not is_instance_valid(ECS.world):
		return null
	return ECS.world.query.with_all([C_Receiving]).execute_one() as E_ReceivingZone


static func _definition(zone: E_ReceivingZone, key: StringName) -> DEF_Package:
	for definition: DEF_Package in zone.supply.packages:
		if definition.key == key:
			return definition
	return null


static func _place_near_player(
	zone: E_ReceivingZone,
	parcel: E_Package,
	index: int,
) -> bool:
	var actor: Entity = DebugTargetResolver.player()
	var actor_node: Node3D = actor as Node as Node3D
	var body: RigidBody3D = parcel as Node as RigidBody3D
	if actor_node == null or body == null or zone.package_parent == null:
		return false

	var column: int = index % SELF_COLUMNS
	@warning_ignore("integer_division")
	var row: int = index / SELF_COLUMNS
	var side_offset: float = (
		float(column) - float(SELF_COLUMNS - 1) * 0.5
	) * SELF_SIDE_SPACING
	var position: Vector3 = (
		actor_node.global_position
		- actor_node.global_basis.z * (SELF_FORWARD_DISTANCE + float(row) * SELF_ROW_SPACING)
		+ actor_node.global_basis.x * side_offset
		+ Vector3.UP * SELF_VERTICAL_OFFSET
	)
	zone.package_parent.add_child(parcel)
	body.global_transform = Transform3D(Basis.IDENTITY, position)
	ECS.world.add_entity(parcel, null, false)
	return true


static func _next_package_id(
	supply_key: StringName,
	day_index: int,
	definition_key: StringName,
) -> String:
	var sequence: int = 1
	while true:
		var candidate: String = "%s%s:%d:%s:%d" % [
			DEBUG_ID_PREFIX,
			String(supply_key),
			day_index,
			String(definition_key),
			sequence,
		]
		if not _identity_exists(candidate):
			return candidate
		sequence += 1
	return ""


static func _identity_exists(package_id: String) -> bool:
	if ReceivingPackageFactory.exists(package_id):
		return true
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger != null:
		for record: PackageRegistrationRecord in ledger.records:
			if record.package_id == package_id:
				return true
	var flow: C_CustomerFlow = CustomerFlowService.current()
	if flow != null:
		for visit: CustomerVisit in flow.visits:
			if visit.package_id == package_id:
				return true
	return false


static func _rollback(spawned: Array[Entity]) -> void:
	for entity: Entity in spawned:
		if not is_instance_valid(entity):
			continue
		var identity: C_Package = entity.get_component(C_Package) as C_Package
		if identity != null:
			_remove_debug_registration(identity.package_id)
		_remove_debug_visit(identity.package_id)
		_remove_live_package(entity)


static func _remove_debug_registration(package_id: String) -> void:
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger == null:
		return
	for record: PackageRegistrationRecord in ledger.records.duplicate():
		if record.package_id == package_id:
			ledger.records.erase(record)


static func _remove_debug_visit(package_id: String) -> void:
	var flow: C_CustomerFlow = CustomerFlowService.current()
	if flow == null:
		return
	for visit: CustomerVisit in flow.visits.duplicate():
		if visit.package_id == package_id:
			flow.visits.erase(visit)


static func _remove_live_package(entity: Entity) -> void:
	if not EntityAvailability.contains(entity, ECS.world):
		return
	CartCargoService.release(entity)
	GrabService.entity_unavailable(entity)
	PackageMarkService.clear_marks(entity)
	ECS.world.remove_entity(entity)
	entity.queue_free()
