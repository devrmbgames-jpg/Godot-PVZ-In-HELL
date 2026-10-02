extends RefCounted
## Atomic one-shot physical extraction. No inventory transfer or customer decision authority.
class_name PackageContentsService

const CONTENTS_COLUMNS: int = 3
const CONTENTS_SPACING: float = 0.65
const GROUND_PROBE_RISE: float = 0.2
const GROUND_PROBE_DEPTH: float = 20.0
const SUPPORT_CLEARANCE: float = 0.03
const GROUND_MASK: int = 31


static func release(package: Entity) -> Array[Entity]:
	var spawned: Array[Entity] = []
	if not EntityAvailability.contains(package, ECS.world):
		return spawned
	var state: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var condition: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	var body: Node3D = package as Node as Node3D
	if state == null or state.released or identity == null or identity.definition == null or body == null:
		return spawned
	if condition == null or condition.opening != C_PackageState.Opening.OPENED:
		return spawned
	var definition: DEF_Package = identity.definition
	if definition.unpack_scene == null or definition.content_quantity < 1 or definition.content_quantity > DEF_Package.MAX_CONTENT_QUANTITY:
		return spawned
	for index: int in definition.content_quantity:
		var node: Node = definition.unpack_scene.instantiate()
		var content: Entity = node as Entity
		if content == null or not node is Node3D:
			node.free()
			for pending: Entity in spawned:
				pending.free()
			return []
		# World pickups authored as starter stacks become individual unpacked objects.
		var components: Array[Component] = content.component_resources.duplicate()
		for component_index: int in components.size():
			var item: C_InventoryItem = components[component_index] as C_InventoryItem
			if item != null:
				var single: C_InventoryItem = C_InventoryItem.new()
				single.definition = item.definition
				single.quantity = 1
				components[component_index] = single
		content.component_resources = components
		spawned.append(content)
	# Commit before registering any body: reentrant lifecycle events cannot duplicate contents.
	state.released = true
	for index: int in spawned.size():
		var content: Entity = spawned[index]
		var node: Node3D = content as Node as Node3D
		var position: Vector3 = body.global_position + definition.unpack_offset
		position += Vector3(index % CONTENTS_COLUMNS, 0, index / CONTENTS_COLUMNS) * CONTENTS_SPACING
		var start: Vector3 = position + Vector3.UP * GROUND_PROBE_RISE
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			start, start + Vector3.DOWN * GROUND_PROBE_DEPTH, GROUND_MASK,
		)
		var parcel_body: PhysicsBody3D = package as Node as PhysicsBody3D
		if parcel_body != null:
			ray.exclude = [parcel_body.get_rid()]
		var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			position.y = (hit.position as Vector3).y - _bottom_height(node) + SUPPORT_CLEARANCE
		body.get_parent().add_child(node)
		node.global_position = position
		ECS.world.add_entity(content, null, false)
	return spawned


static func _bottom_height(node: Node3D) -> float:
	var lowest: float = 0.0
	for child: Node in node.find_children("*", "CollisionShape3D", true, false):
		var collision: CollisionShape3D = child as CollisionShape3D
		if collision.shape == null or collision.disabled:
			continue
		var mesh: ArrayMesh = collision.shape.get_debug_mesh()
		var relative: Transform3D = collision.transform
		var ancestor: Node = collision.get_parent()
		while ancestor != null and ancestor != node:
			if ancestor is Node3D:
				relative = (ancestor as Node3D).transform * relative
			ancestor = ancestor.get_parent()
		var bounds: AABB = relative * mesh.get_aabb()
		lowest = minf(lowest, bounds.position.y)
	return lowest
