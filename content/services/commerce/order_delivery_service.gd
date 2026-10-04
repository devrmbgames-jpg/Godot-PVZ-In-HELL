extends RefCounted
## One physical paid-order commit. Fulfilled records are retained after consumption.
class_name OrderDeliveryService

const OCCUPANCY_MASK: int = 0xFFFFFFFF


static func key_for(delivery: PendingDelivery) -> String:
	return "order/%s" % delivery.delivery_id


## Courier charges only for definitions with a supported physical fulfillment prefab.
static func can_fulfill_definition(item: DEF_InventoryItem) -> bool:
	if item == null or item.world_pickup_scene.is_empty() or not ResourceLoader.exists(item.world_pickup_scene):
		return false
	if item.kind == DEF_InventoryItem.Kind.FURNITURE:
		var furniture: Entity = FurniturePlacement.create_validated(item)
		if furniture == null:
			return false

		furniture.free()
		return true

	var packed: PackedScene = load(item.world_pickup_scene) as PackedScene
	var node: Node = packed.instantiate() if packed != null else null
	if node == null:
		return false

	var valid: bool = false
	if node is E_InventoryPickup and node is RigidBody3D:
		var collision: CollisionShape3D = node.get_node_or_null("Collision") as CollisionShape3D
		if collision != null and not collision.disabled and collision.shape != null:
			for component: Component in (node as E_InventoryPickup).component_resources:
				if component is C_InventoryItem:
					valid = true
					break

	node.free()
	return valid


static func fulfill_one(zone: Entity, state: C_OrderReceiving, commerce: C_Commerce, day: int) -> bool:
	if not EntityAvailability.contains(zone, ECS.world) or state == null or commerce == null or day < 1:
		return false

	var anchor: Node3D = zone as Node as Node3D
	if anchor == null or not anchor.is_inside_tree() or state.columns < 1 or state.rows < 1 or state.spacing.x <= 0.0 or state.spacing.y <= 0.0:
		return false

	for delivery: PendingDelivery in commerce.pending_deliveries:
		if delivery.fulfilled or delivery.delivery_day > day:
			continue
		if delivery.delivery_id.is_empty() or delivery.item == null or delivery.quantity < 1 or delivery.quantity > delivery.item.maximum_stack:
			state.blocked = true
			return false

		for existing: Entity in ECS.world.query.with_all([C_PersistentIdentity]).execute():
			var identity: C_PersistentIdentity = existing.get_component(C_PersistentIdentity) as C_PersistentIdentity
			if identity.key == key_for(delivery):
				delivery.fulfilled = true
				state.blocked = false
				return true
		if delivery.item.kind == DEF_InventoryItem.Kind.FURNITURE:
			if delivery.quantity != 1:
				state.blocked = true
				return false

			for index: int in state.columns * state.rows:
				var pose: Transform3D = anchor.global_transform
				pose.origin += pose.basis * Vector3((index % state.columns) * state.spacing.x, 0, (index / state.columns) * state.spacing.y)
				var proposal: PreparedFurniture = FurniturePlacement.prepare(delivery.item, anchor, pose)
				if proposal == null:
					continue

				delivery.fulfilled = true
				FurniturePlacement.commit(proposal, key_for(delivery))
				state.blocked = false
				return true

			state.blocked = true
			return false

		var packed: PackedScene = load(delivery.item.world_pickup_scene) as PackedScene if not delivery.item.world_pickup_scene.is_empty() else null
		var pickup: E_InventoryPickup = packed.instantiate() as E_InventoryPickup if packed != null else null
		if pickup == null:
			state.blocked = true
			return false

		var collision: CollisionShape3D = pickup.get_node_or_null("Collision") as CollisionShape3D
		var body: RigidBody3D = pickup as Node as RigidBody3D
		if collision == null or collision.shape == null or body == null:
			pickup.free()
			state.blocked = true
			return false

		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.margin = maxf(0.0, state.collision_margin)
		query.collision_mask = OCCUPANCY_MASK
		var space: PhysicsDirectSpaceState3D = anchor.get_world_3d().direct_space_state
		for index: int in state.columns * state.rows:
			var pose: Transform3D = anchor.global_transform
			pose.origin += pose.basis * Vector3((index % state.columns) * state.spacing.x, 0.0, (index / state.columns) * state.spacing.y)
			query.transform = pose * collision.transform
			if not space.intersect_shape(query, 1).is_empty():
				continue

			var components: Array[Component] = pickup.component_resources.duplicate()
			for component_index: int in components.size():
				if components[component_index] is C_InventoryItem:
					var item: C_InventoryItem = C_InventoryItem.new()
					item.definition = delivery.item
					item.quantity = delivery.quantity
					components[component_index] = item
			var identity: C_PersistentIdentity = C_PersistentIdentity.new()
			identity.key = key_for(delivery)
			components.append(identity)
			pickup.component_resources = components
			anchor.add_child(pickup)
			body.global_transform = pose
			ECS.world.add_entity(pickup, null, false)
			delivery.fulfilled = true
			state.blocked = false
			return true

		pickup.free()
		state.blocked = true
		return false

	state.blocked = false
	return false
