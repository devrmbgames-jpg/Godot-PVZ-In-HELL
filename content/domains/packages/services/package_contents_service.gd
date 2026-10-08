extends RefCounted
## Однократно фиксирует содержимое коробки; свободная позиция и остаток принадлежат очереди лута.
class_name PackageContentsService

const CONTENTS_COLUMNS: int = 3
const CONTENTS_SPACING: float = 0.65
const SPILL_CLEARANCE: float = 0.15
const SPILL_ITEMS_PER_RING: int = 6

#region Состояние и извлечение
## released — единственный признак пустой оболочки, в том числе с ожидающим остатком после загрузки.
static func is_empty(package: Entity) -> bool:
	if not is_instance_valid(package):
		return false

	var contents: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	return contents != null and contents.released

## Фиксирует состав открытой целой коробки один раз; возвращает только безопасно размещённые тела.
## captured_actor_id preserves committed attribution when the optional live initiator is unavailable.
static func release(package: Entity, actor: Entity = null, captured_actor_id: String = "") -> Array[Entity]:
	if not EntityAvailability.contains(package, ECS.world):
		return []

	var state: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var condition: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	var body: RigidBody3D = package as Node as RigidBody3D
	if state == null or state.released or identity == null or identity.definition == null or body == null:
		return []
	if condition == null or condition.opening != C_PackageState.Opening.OPENED or condition.damage == C_PackageState.Damage.DESTROYED:
		return []

	var definition: DEF_Package = identity.definition
	if definition.unpack_scene == null or definition.content_quantity < 1 or definition.content_quantity > DEF_Package.MAX_CONTENT_QUANTITY:
		return []
	var queue: C_LootDrops = LootDropService.current()
	if queue == null:
		return []
	var scenes: Array[PackedScene] = []
	for index: int in definition.content_quantity:
		scenes.append(definition.unpack_scene)
	var items: Array[Entity] = LootDropService.prepare(scenes)
	if items.is_empty():
		return []

	var template: PendingLootDrop = PendingLootDrop.new()
	template.anchor = body.global_position
	template.source_id = package.id
	template.actor_id = captured_actor_id if not captured_actor_id.is_empty() else (actor.id if is_instance_valid(actor) else "")
	template.package_id = identity.package_id
	template.airborne = definition.spill_contents
	template.activate_hazard = definition.activate_contents_hazard
	template.opening_hazard_path = definition.hazard_on_opened.resource_path if definition.hazard_on_opened != null else ""
	var origins: PackedVector3Array = _origins(body, items, definition)

	# Guard и состав фиксируются до регистрации тел; повтор события не создаёт вторую партию.
	state.released = true
	condition.leaking = false
	body.mass = definition.empty_mass_kg
	GrabService.refresh_carry_mass(package)
	return LootDropService.enqueue(queue, "package/" + identity.package_id + "/contents", items, template, origins)

static func _origins(body: RigidBody3D, items: Array[Entity], definition: DEF_Package) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	var top: float = solver.bounds_at(body.global_transform).end.y if solver.prepare(body) else body.global_position.y
	var first: RigidBody3D = items[0] as Node as RigidBody3D
	var bottom: float = solver.bounds_at(Transform3D(first.transform.basis, Vector3.ZERO)).position.y if solver.prepare(first) else 0.0
	for index: int in items.size():
		var position: Vector3 = body.global_position + definition.unpack_offset
		var ring: int = index / SPILL_ITEMS_PER_RING
		var ring_size: int = mini(SPILL_ITEMS_PER_RING, items.size() - ring * SPILL_ITEMS_PER_RING)
		var angle: float = TAU * float(index % SPILL_ITEMS_PER_RING) / ring_size
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		if definition.spill_contents:
			position.y = top - bottom + SPILL_CLEARANCE
			position += direction * CONTENTS_SPACING * (ring + 1)
			(items[index] as Node as RigidBody3D).linear_velocity = (direction + Vector3.UP) * definition.spill_speed
		else:
			position += Vector3(index % CONTENTS_COLUMNS, 0.0, index / CONTENTS_COLUMNS) * CONTENTS_SPACING
		result.append(position)
	return result
#endregion
