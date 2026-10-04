extends RefCounted
## Sole allocator of hidden package history/debug IDs.
class_name PackageHistoryService

const SMALL_MAX_METERS: float = 0.50
const MEDIUM_MAX_METERS: float = 0.80
const LARGE_MAX_METERS: float = 1.50


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


static func decode(value: String) -> PackageHistoryId:
	return PackageHistoryId.parse(value)


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
