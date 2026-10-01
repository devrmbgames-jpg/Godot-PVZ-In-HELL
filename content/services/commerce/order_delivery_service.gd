extends RefCounted
## One physical paid-order commit. Fulfilled records are retained after consumption.
class_name OrderDeliveryService

const OCCUPANCY_MASK: int = 0xFFFFFFFF


static func key_for(delivery: PendingDelivery) -> String:
	return "order/%s" % delivery.delivery_id


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
		var packed: PackedScene = load(delivery.item.world_pickup_scene) as PackedScene if not delivery.item.world_pickup_scene.is_empty() else null
		var pickup: E_InventoryPickup = packed.instantiate() as E_InventoryPickup if packed != null else null
		if pickup == null:
			state.blocked = true
			return false
		var collision: CollisionShape3D = pickup.get_node_or_null("Collision") as CollisionShape3D
		var body: StaticBody3D = pickup as Node as StaticBody3D
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
