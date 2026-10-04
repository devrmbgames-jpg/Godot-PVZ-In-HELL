extends RefCounted
## Atomic one-shot physical extraction. No inventory transfer or customer decision authority.
class_name PackageContentsService

const CONTENTS_COLUMNS: int = 3
const CONTENTS_SPACING: float = 0.65
const GROUND_PROBE_RISE: float = 0.2
const GROUND_PROBE_DEPTH: float = 20.0
const SUPPORT_CLEARANCE: float = 0.03
const GROUND_MASK: int = 31
const SPILL_CLEARANCE: float = 0.15
const SPILL_ITEMS_PER_RING: int = 6


## released — единственный признак пустой оболочки, в том числе после загрузки.
static func is_empty(package: Entity) -> bool:
	if not is_instance_valid(package):
		return false

	var contents: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	return contents != null and contents.released


static func release(package: Entity, actor: Entity = null) -> Array[Entity]:
	var spawned: Array[Entity] = []
	if not EntityAvailability.contains(package, ECS.world):
		return spawned

	var state: C_PackageContents = package.get_component(C_PackageContents) as C_PackageContents
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var condition: C_PackageState = package.get_component(C_PackageState) as C_PackageState
	var body: Node3D = package as Node as Node3D
	if state == null or state.released or identity == null or identity.definition == null or body == null:
		return spawned
	if condition == null or condition.opening != C_PackageState.Opening.OPENED or condition.damage == C_PackageState.Damage.DESTROYED:
		return spawned

	var definition: DEF_Package = identity.definition
	if definition.unpack_scene == null or definition.content_quantity < 1 or definition.content_quantity > DEF_Package.MAX_CONTENT_QUANTITY:
		return spawned

	for index: int in definition.content_quantity:
		var node: Node = definition.unpack_scene.instantiate()
		var content: Entity = node as Entity
		if content == null or not node is RigidBody3D:
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
	condition.leaking = false

	var parcel_body: RigidBody3D = package as Node as RigidBody3D
	if parcel_body != null:
		parcel_body.mass = definition.empty_mass_kg
		GrabService.refresh_carry_mass(package)
	var top: float = _top_height(body) if definition.spill_contents else 0.0
	for index: int in spawned.size():
		var content: Entity = spawned[index]
		var node: RigidBody3D = content as Node as RigidBody3D
		var position: Vector3 = body.global_position + definition.unpack_offset
		var ring: int = index / SPILL_ITEMS_PER_RING
		var ring_size: int = mini(SPILL_ITEMS_PER_RING, spawned.size() - ring * SPILL_ITEMS_PER_RING)
		var angle: float = TAU * float(index % SPILL_ITEMS_PER_RING) / ring_size
		var direction: Vector3 = Vector3(cos(angle), 0, sin(angle))
		if definition.spill_contents:
			position.y = body.global_position.y + top - _bottom_height(node) + SPILL_CLEARANCE
			position += direction * CONTENTS_SPACING * (ring + 1)
		else:
			position += Vector3(index % CONTENTS_COLUMNS, 0, index / CONTENTS_COLUMNS) * CONTENTS_SPACING
		var start: Vector3 = position + Vector3.UP * GROUND_PROBE_RISE
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			start, start + Vector3.DOWN * GROUND_PROBE_DEPTH, GROUND_MASK,
		)
		if parcel_body != null:
			ray.exclude = [parcel_body.get_rid()]
		var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
		if not definition.spill_contents and not hit.is_empty():
			position.y = (hit.position as Vector3).y - _bottom_height(node) + SUPPORT_CLEARANCE
		body.get_parent().add_child(node)
		node.global_position = position
		ECS.world.add_entity(content, null, false)
		if definition.spill_contents:
			node.linear_velocity = (direction + Vector3.UP) * definition.spill_speed
		if definition.activate_contents_hazard:
			HazardEmitter.activate(content, actor)
	# Opening effects belong to the first real content object, not to the empty box.
	if definition.hazard_on_opened != null:
		HazardEmitter.emit_scene(spawned[0], definition.hazard_on_opened, "%s:opened:%s" % [identity.package_id, definition.hazard_on_opened.resource_path], actor, identity.package_id)
	for effect: Entity in ECS.world.query.with_relationship([Relationship.new(R_HazardFollow.new(), package)]).execute().duplicate():
		var binding: Relationship = HazardFollowService.binding(effect)
		HazardFollowService.replace(effect, spawned[0], binding.relation as R_HazardFollow)
	return spawned


static func _top_height(node: Node3D) -> float:
	var highest: float = 0.0
	for child: Node in node.find_children("*", "CollisionShape3D", true, false):
		var collision: CollisionShape3D = child as CollisionShape3D
		if collision.shape == null or collision.disabled:
			continue

		var bounds: AABB = collision.global_transform * collision.shape.get_debug_mesh().get_aabb()
		highest = maxf(highest, bounds.end.y - node.global_position.y)
	return highest


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
