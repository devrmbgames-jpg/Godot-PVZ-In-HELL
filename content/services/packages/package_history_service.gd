extends RefCounted
## Выделяет скрытые ID и хранит поступления независимо от физической коробки.
class_name PackageHistoryService

const SMALL_MAX_METERS: float = 0.50
const MEDIUM_MAX_METERS: float = 0.80
const LARGE_MAX_METERS: float = 1.50


#region Постоянный ID истории
## Читает постоянную запись по package_id, включая поступление без номера выдачи.
static func record_for(package_id: String, registry: C_PackageLedger = null) -> PackageRegistrationRecord:
	var source: C_PackageLedger = registry if registry != null else _ledger()
	if source == null:
		return null
	for record: PackageRegistrationRecord in source.records:
		if record.package_id == package_id:
			return record
	return null


## Однократно записывает реальное поступление; сканирование и номер выдачи не назначает.
static func record_arrival(parcel: Entity, day_index: int) -> PackageRegistrationRecord:
	if not EntityAvailability.contains(parcel, ECS.world) or day_index < 1:
		return null
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var registry: C_PackageLedger = _ledger()
	if identity == null or identity.package_id.is_empty() or identity.definition == null or registry == null:
		return null
	var existing: PackageRegistrationRecord = record_for(identity.package_id, registry)
	if existing != null:
		return existing
	var history_id: String = ensure_history_id(parcel, day_index)
	if history_id.is_empty():
		return null

	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = identity.package_id
	record.history_id = history_id
	record.received_day = day_index
	record.definition = identity.definition
	registry.records.append(record)
	return record


## Сохраняет допустимый существующий ID либо выделяет новый для дня; ошибка возвращает пустую строку.
static func ensure_history_id(parcel: Entity, day_index: int) -> String:
	if not is_instance_valid(parcel) or day_index < 1:
		return ""

	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	if identity == null or identity.definition == null:
		return ""
	if not identity.history_id.is_empty():
		return identity.history_id if PackageHistoryId.parse(identity.history_id) != null else ""

	var mass_tenths: int = roundi(identity.definition.mass_kg * PackageHistoryId.MASS_SCALE)
	if mass_tenths < 0 or mass_tenths > PackageHistoryId.MAX_MASS_TENTHS:
		push_error("Package mass cannot be represented in history ID: %.2f kg" % identity.definition.mass_kg)
		return ""

	var history: PackageHistoryId = PackageHistoryId.new()
	history.day_index = day_index
	history.number = _allocate_number(day_index)
	if history.number < 1:
		return ""

	history.hazard_class = identity.definition.history_hazard_class
	history.size_class = _size_class(parcel)
	history.mass_tenths_kg = mass_tenths
	identity.history_id = history.serialize()
	return identity.history_id


## Декодирует и проверяет скрытый ID; возвращает null при неверном формате.
static func decode(value: String) -> PackageHistoryId:
	return PackageHistoryId.parse(value)


#endregion

#region Счётчик и диагностический размер
static func _allocate_number(day_index: int) -> int:
	var registry: C_PackageLedger = _ledger()
	if registry == null:
		return 0
	if registry.history_sequence_day != day_index:
		registry.history_sequence_day = day_index
		registry.next_history_number = 1
	var number: int = registry.next_history_number
	registry.next_history_number += 1
	return number


static func _ledger() -> C_PackageLedger:
	if not is_instance_valid(ECS.world):
		return null

	var session: Entity = ECS.world.query.with_all([C_PackageLedger]).execute_one()
	return session.get_component(C_PackageLedger) as C_PackageLedger if session != null else null


static func _size_class(parcel: Entity) -> PackageHistoryId.SizeClass:
	var node: Node = parcel as Node
	if node == null:
		return PackageHistoryId.SizeClass.MEDIUM

	var collision: CollisionShape3D = node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null or collision.shape == null:
		return PackageHistoryId.SizeClass.MEDIUM

	var longest: float = MEDIUM_MAX_METERS
	if collision.shape is BoxShape3D:
		var box: BoxShape3D = collision.shape as BoxShape3D
		longest = maxf(box.size.x, maxf(box.size.y, box.size.z))
	elif collision.shape is SphereShape3D:
		var sphere: SphereShape3D = collision.shape as SphereShape3D
		longest = sphere.radius * 2.0
	elif collision.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision.shape as CapsuleShape3D
		longest = maxf(capsule.radius * 2.0, capsule.height)
	elif collision.shape is CylinderShape3D:
		var cylinder: CylinderShape3D = collision.shape as CylinderShape3D
		longest = maxf(cylinder.radius * 2.0, cylinder.height)

	if longest <= SMALL_MAX_METERS:
		return PackageHistoryId.SizeClass.SMALL
	if longest <= MEDIUM_MAX_METERS:
		return PackageHistoryId.SizeClass.MEDIUM
	if longest <= LARGE_MAX_METERS:
		return PackageHistoryId.SizeClass.LARGE
	return PackageHistoryId.SizeClass.OVERSIZED

#endregion
