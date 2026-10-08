extends RefCounted
## Создаёт оплаченные товары на карте; исполненные записи сохраняются после расходования.
class_name OrderDeliveryService

const OCCUPANCY_MASK: int = 0xFFFFFFFF


#region Определение заказа
## Строит устойчивый ключ физического товара из ID оплаченной доставки.
static func key_for(delivery: PendingDelivery) -> String:
	return "order/%s" % delivery.delivery_id


## Проверяет поддерживаемую физическую сцену до оплаты доставки; тестовый экземпляр освобождается.
static func can_fulfill_definition(item: DEF_InventoryItem) -> bool:
	if item == null or item.world_pickup_scene.is_empty() or not ResourceLoader.exists(item.world_pickup_scene):
		return false
	if item.kind == DEF_InventoryItem.Kind.FURNITURE:
		var furniture: Entity = FurniturePlacement.create_validated(item)
		if furniture == null:
			return false

		var solver: ItemPlacementSolver = ItemPlacementSolver.new()
		var supported: bool = solver.prepare(furniture as Node as PhysicsBody3D)
		furniture.free()
		return supported

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


#endregion

#region Однократная утренняя выдача
## Исполняет первый готовый заказ или признаёт уже созданный по ключу; занятость сохраняет заказ.
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

		var key: String = key_for(delivery)
		if _existing(state, key) != null:
			delivery.fulfilled = true
			state.blocked = false
			return true
		if delivery.item.kind == DEF_InventoryItem.Kind.FURNITURE:
			return _furniture(zone, state, delivery)

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
			pickup.id = key
			body.transform = anchor.global_transform.affine_inverse() * pose
			anchor.add_child(pickup)
			ECS.world.add_entity(pickup, null, false)
			state.goods[key] = weakref(pickup)
			delivery.fulfilled = true
			state.blocked = false
			return true

		pickup.free()
		state.blocked = true
		return false

	state.blocked = false
	state.exhausted = true
	return false

#endregion

#region Полная форма мебели и резервы
static func _furniture(zone: Entity, state: C_OrderReceiving, delivery: PendingDelivery) -> bool:
	var marker: Node3D = zone.get_node_or_null(state.furniture_anchor_path) as Node3D if not state.furniture_anchor_path.is_empty() else null
	if marker == null or delivery.quantity != 1 or state.furniture_placement == null:
		state.blocked = true
		return false
	var parent: Node3D = marker.get_parent() as Node3D if marker != zone else marker
	var entity: Entity = FurniturePlacement.create_validated(delivery.item)
	if parent == null or entity == null:
		if entity != null:
			entity.free()
		state.blocked = true
		return false

	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	if not solver.prepare(entity as Node as PhysicsBody3D):
		entity.free()
		state.blocked = true
		return false
	var frame: int = Engine.get_physics_frames()
	if state.reservation_frame != frame:
		state.reservations.clear()
		state.reservation_frame = frame
	var origin: Transform3D = marker.global_transform
	origin.basis = origin.basis.orthonormalized()
	var result: ItemPlacementSolver.Result = solver.find(marker.get_world_3d().direct_space_state, origin, state.furniture_placement, state.reservations, [])
	if not result.available:
		entity.free()
		state.blocked = true
		return false

	var proposal: PreparedFurniture = PreparedFurniture.new()
	proposal.entity = entity
	proposal.parent = parent
	proposal.world_pose = result.pose
	entity.id = key_for(delivery)
	FurniturePlacement.commit(proposal, key_for(delivery))
	state.goods[key_for(delivery)] = weakref(entity)
	state.reservations.append(result.bounds)
	delivery.fulfilled = true
	state.blocked = false
	return true
#endregion

#region Производный контекст выдачи
## Сбрасывает таймеры, резервы и слабые ссылки после восстановления World; заказы не меняет.
static func reset_context(state: C_OrderReceiving) -> void:
	state.delivery_revision += 1
	state.delivery_queued = false
	state.retry_remaining = 0.0
	state.attempt_day = 0
	state.exhausted = false
	state.blocked = false
	state.identity_index_ready = false
	state.goods.clear()
	state.reservations.clear()
	state.reservation_frame = -1

static func _existing(state: C_OrderReceiving, key: String) -> Entity:
	if not state.identity_index_ready:
		# Один индекс при старте/restore, включая прежние товары с произвольным Entity.id.
		for entity: Entity in ECS.world.query.with_all([C_PersistentIdentity]).execute():
			var identity: C_PersistentIdentity = entity.get_component(C_PersistentIdentity) as C_PersistentIdentity
			if identity.key.begins_with("order/"):
				state.goods[identity.key] = weakref(entity)
		state.identity_index_ready = true

	var reference: WeakRef = state.goods.get(key)
	var existing: Entity = reference.get_ref() as Entity if reference != null else null
	return existing if EntityAvailability.contains(existing, ECS.world) else null
#endregion
