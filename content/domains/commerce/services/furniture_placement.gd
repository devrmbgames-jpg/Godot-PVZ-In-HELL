extends RefCounted
## Проверяет опору и свободный объём до оплаты; после создания движение принадлежит физике.
class_name FurniturePlacement

const GROUND_MASK: int = 31
const OCCUPANCY_MASK: int = 0xFFFFFFFF
const GROUND_PROBE_RISE: float = 0.75
const GROUND_PROBE_DEPTH: float = 20.0
const SUPPORT_CLEARANCE: float = 0.05
const COLLISION_MARGIN: float = 0.01
const MINIMUM_SUPPORT_NORMAL: float = 0.75


#region Подготовка тела
## Проверяет опору и объём в мировой позе; возвращённую заготовку нужно разместить или освободить.
static func prepare(item: DEF_InventoryItem, parent: Node3D, pose: Transform3D) -> PreparedFurniture:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null

	var entity: Entity = create_validated(item)
	if entity == null:
		return null

	var node: Node3D = entity as Node as Node3D
	var bounds: AABB = _bounds_for(node)
	pose.basis = pose.basis.orthonormalized()
	var space: PhysicsDirectSpaceState3D = parent.get_world_3d().direct_space_state
	var start: Vector3 = pose.origin + Vector3.UP * GROUND_PROBE_RISE
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, start + Vector3.DOWN * GROUND_PROBE_DEPTH, GROUND_MASK)
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < MINIMUM_SUPPORT_NORMAL:
		node.free()
		return null

	var rotated: AABB = Transform3D(pose.basis, Vector3.ZERO) * bounds
	pose.origin.y = (hit.position as Vector3).y - rotated.position.y + SUPPORT_CLEARANCE
	var volume: BoxShape3D = BoxShape3D.new()
	volume.size = bounds.size
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = volume
	query.transform = pose * Transform3D(Basis.IDENTITY, bounds.get_center())
	query.margin = COLLISION_MARGIN
	query.collision_mask = OCCUPANCY_MASK
	if not space.intersect_shape(query, 1).is_empty():
		node.free()
		return null

	var proposal: PreparedFurniture = PreparedFurniture.new()
	proposal.entity = entity
	proposal.parent = parent
	proposal.world_pose = pose
	return proposal


## Создаёт вне дерева проверенное тело мебели; вызывающий обязан освободить или разместить его.
static func create_validated(item: DEF_InventoryItem) -> Entity:
	if item == null or item.kind != DEF_InventoryItem.Kind.FURNITURE or item.maximum_stack != 1 or item.world_pickup_scene.is_empty() or not ResourceLoader.exists(item.world_pickup_scene):
		return null

	var packed: PackedScene = load(item.world_pickup_scene) as PackedScene
	var node: Node = packed.instantiate() if packed != null else null
	var entity: Entity = node as Entity
	var body: RigidBody3D = node as RigidBody3D
	if entity == null or body == null:
		if node != null:
			node.free()
		return null
	if not _bounds_for(body).has_volume():
		node.free()
		return null
	return entity


#endregion

#region Габариты и однократное размещение
static func _bounds_for(node: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var has_shape: bool = false
	for child: Node in node.find_children("*", "CollisionShape3D", true, false):
		var collider: CollisionShape3D = child as CollisionShape3D
		if collider.disabled or collider.shape == null:
			continue

		var local: Transform3D = collider.transform
		var ancestor: Node = collider.get_parent()
		while ancestor != node and ancestor != null:
			if ancestor is Node3D:
				local = (ancestor as Node3D).transform * local
			ancestor = ancestor.get_parent()
		var shape_bounds: AABB = local * collider.shape.get_debug_mesh().get_aabb()
		bounds = bounds.merge(shape_bounds) if has_shape else shape_bounds
		has_shape = true
	return bounds


## Однократно размещает заготовку, добавляет устойчивый ключ и регистрирует тело в World.
static func commit(proposal: PreparedFurniture, key: String) -> void:
	var identity: C_PersistentIdentity = C_PersistentIdentity.new()
	identity.key = key
	proposal.entity.component_resources.append(identity)
	var body: Node3D = proposal.entity as Node as Node3D
	# Создание/восстановление — однократная граница записи позы; дальше движением владеет физика.
	body.transform = proposal.parent.global_transform.affine_inverse() * proposal.world_pose
	proposal.parent.add_child(body)
	ECS.world.add_entity(proposal.entity, null, false)

#endregion
