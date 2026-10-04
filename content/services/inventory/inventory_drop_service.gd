extends RefCounted
## Whole-stack inventory-to-world boundary. Rejections retain ownership and quantity.
class_name InventoryDropService

const FORWARD_DISTANCE: float = 0.9
const SIDE_DISTANCE: float = 0.6
const PROBE_RISE: float = 0.75
const PROBE_DEPTH: float = 3.0
const PATH_PROBE_HEIGHT: float = 0.5
const SUPPORT_CLEARANCE: float = 0.03
const MINIMUM_SUPPORT_NORMAL_Y: float = 0.75
const COLLISION_MASK: int = 31


static func drop_reason(actor: Entity, item: Entity) -> String:
	if not GrabService.holder_available(actor) or actor.has_component(C_Death):
		return "Игрок недоступен"

	var inventory: C_Inventory = actor.get_component(C_Inventory) as C_Inventory
	if inventory == null or inventory.use_in_progress or inventory.transfer_in_progress:
		return "Дождитесь завершения действия"
	if not EntityAvailability.contains(item, ECS.world) or InventoryService.owner_for(item) != actor:
		return "Предмет не принадлежит игроку"

	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	if state == null or state.definition == null or state.quantity < 1 or state.quantity > state.definition.maximum_stack or state.transfer_in_progress or not state.pending_use_id.is_empty():
		return "Стек недоступен"
	if not (actor as Node) is Node3D or state.definition.world_pickup_scene.is_empty() or not ResourceLoader.exists(state.definition.world_pickup_scene, "PackedScene"):
		return "Предмет нельзя выложить в мир"
	return ""


static func drop(actor: Entity, item: Entity) -> bool:
	if not drop_reason(actor, item).is_empty():
		return false

	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	var prefab: PackedScene = load(state.definition.world_pickup_scene) as PackedScene
	var instance: Node = prefab.instantiate()
	var pickup: E_InventoryPickup = instance as E_InventoryPickup
	var collider: CollisionShape3D = instance.get_node_or_null("Collision") as CollisionShape3D
	if pickup == null or not instance is RigidBody3D or collider == null or collider.shape == null:
		instance.free()
		return false

	var components: Array[Component] = pickup.component_resources.duplicate()
	var replaced: bool = false
	for index: int in components.size():
		if components[index] is C_InventoryItem:
			var stack: C_InventoryItem = C_InventoryItem.new()
			stack.definition = state.definition
			stack.quantity = state.quantity
			components[index] = stack
			replaced = true
	if not replaced:
		instance.free()
		return false

	var body: RigidBody3D = instance as RigidBody3D
	var position: Variant = _placement(actor, collider)
	if not position is Vector3:
		instance.free()
		return false

	pickup.component_resources = components
	var inventory: C_Inventory = actor.get_component(C_Inventory) as C_Inventory
	inventory.transfer_in_progress = true
	state.transfer_in_progress = true
	var parent: Node = actor.get_parent()
	# Scene creation is the explicit physical placement boundary, before entering simulation.
	var pose: Transform3D = Transform3D(Basis.IDENTITY, position as Vector3)
	body.transform = (parent as Node3D).global_transform.affine_inverse() * pose if parent is Node3D else pose
	parent.add_child(body)
	ECS.world.add_entity(pickup, null, false)
	ECS.world.remove_entity(item)
	inventory.transfer_in_progress = false
	return true


## Releases NPC possessions once at the death boundary using their ordinary pickup prefabs.
static func release_on_death(owner: Entity) -> void:
	var spatial: Node3D = owner as Node as Node3D
	if spatial == null:
		return

	for item: Entity in InventoryService.items(owner).duplicate():
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		if state == null or state.definition == null or state.definition.world_pickup_scene.is_empty():
			continue

		var prefab: PackedScene = load(state.definition.world_pickup_scene) as PackedScene
		var pickup: E_InventoryPickup = prefab.instantiate() as E_InventoryPickup if prefab != null else null
		if pickup == null:
			continue

		var components: Array[Component] = pickup.component_resources.duplicate()
		for index: int in components.size():
			if components[index] is C_InventoryItem:
				var stack: C_InventoryItem = C_InventoryItem.new()
				stack.definition = state.definition
				stack.quantity = state.quantity
				components[index] = stack
		pickup.component_resources = components
		state.transfer_in_progress = true
		owner.get_parent().add_child(pickup)
		(pickup as Node as Node3D).global_position = spatial.global_position + Vector3(0.6, 0.4, 0.0)
		ECS.world.add_entity(pickup, null, false)
		ECS.world.remove_entity(item)


static func _placement(actor: Entity, collider: CollisionShape3D) -> Variant:
	var node: Node3D = actor as Node as Node3D
	var basis: Basis = node.global_basis
	var character: E_PhysicalCharacter = actor as E_PhysicalCharacter
	if character != null and character.head_axis_y != null:
		basis = character.head_axis_y.global_basis
	var forward: Vector3 = Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var side: Vector3 = Vector3(basis.x.x, 0, basis.x.z).normalized()
	var space: PhysicsDirectSpaceState3D = node.get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.collision_mask = COLLISION_MASK

	var actor_body: PhysicsBody3D = node as PhysicsBody3D
	if actor_body != null:
		query.exclude = [actor_body.get_rid()]
	var bounds: AABB = collider.transform * collider.shape.get_debug_mesh().get_aabb()
	for offset: float in [0.0, -SIDE_DISTANCE, SIDE_DISTANCE]:
		var position: Vector3 = node.global_position + forward * FORWARD_DISTANCE + side * offset
		var path_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(node.global_position + Vector3.UP * PATH_PROBE_HEIGHT, position + Vector3.UP * PATH_PROBE_HEIGHT, COLLISION_MASK)
		path_ray.exclude = query.exclude
		if not space.intersect_ray(path_ray).is_empty():
			continue

		var start: Vector3 = position + Vector3.UP * PROBE_RISE
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, start + Vector3.DOWN * PROBE_DEPTH, COLLISION_MASK)
		ray.exclude = query.exclude
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector3).y < MINIMUM_SUPPORT_NORMAL_Y:
			continue

		position.y = (hit.position as Vector3).y - bounds.position.y + SUPPORT_CLEARANCE
		query.transform = Transform3D(Basis.IDENTITY, position) * collider.transform
		if space.intersect_shape(query, 1).is_empty():
			return position
	return null
