extends RefCounted
## Фиксирует состав дропа один раз и создаёт только предметы с проверенной физической позицией.
class_name LootDropService

#region Сессия и подготовка партии
## Читает готовую очередь сессии; отсутствие сессии допустимо вне gameplay World.
static func current() -> C_LootDrops:
	if not is_instance_valid(ECS.world):
		return null

	var session: Entity = ECS.world.query.with_all([C_DayCycle]).execute_one()
	if session == null:
		return null

	var queue: C_LootDrops = session.get_component(C_LootDrops) as C_LootDrops
	assert(queue != null, "Day session must compose its loot queue before native registration")
	return queue

## Проверяет всю партию до изменения источника и превращает авторские стеки в отдельные предметы.
static func prepare(scenes: Array[PackedScene], require_inventory: bool = false) -> Array[Entity]:
	var items: Array[Entity] = []
	for scene: PackedScene in scenes:
		var node: Node = scene.instantiate() if scene != null else null
		var item: Entity = node as Entity
		var body: RigidBody3D = node as RigidBody3D
		var solver: ItemPlacementSolver = ItemPlacementSolver.new()
		var valid_item: bool = item != null and body != null \
			and GameplayResourcePaths.is_entity_scene_path(scene.resource_path) \
			and solver.prepare(body) and _single_item(item, require_inventory)
		if valid_item:
			# Reject incomplete capabilities before the source commits its one-time manifest.
			var preview_id: String = item.id if not item.id.is_empty() \
				else "preview/loot/%d" % items.size()
			var context: EntitySpawnContext = EntityCompositionService.context_for(item,
				ECS.world, preview_id)
			valid_item = EntityCompositionService.build_plan(context).valid()
		if not valid_item:
			if node != null:
				node.free()
			for prepared: Entity in items:
				prepared.free()
			return []
		items.append(item)
	return items

## Записывает manifest до регистрации тел; возвращает только действительно размещённые предметы.
static func enqueue(queue: C_LootDrops, batch_id: String, items: Array[Entity], template: PendingLootDrop, origins: PackedVector3Array = PackedVector3Array()) -> Array[Entity]:
	var spawned: Array[Entity] = []
	if queue == null or queue.committed_batches.has(batch_id):
		for item: Entity in items:
			item.free()
		return spawned

	queue.committed_batches[batch_id] = true
	var records: Array[PendingLootDrop] = []
	for index: int in items.size():
		var record: PendingLootDrop = template.duplicate() as PendingLootDrop
		record.batch_id = batch_id
		record.drop_id = "loot/%s/%d" % [batch_id, index]
		record.scene_path = items[index].scene_file_path
		record.origin = origins[index] if index < origins.size() else template.origin
		record.velocity = (items[index] as Node as RigidBody3D).linear_velocity
		record.primary = index == 0
		records.append(record)
	queue.pending.append_array(records)

	for index: int in items.size():
		var placed: bool = index < queue.placement.initial_budget and _place(queue, records[index], items[index])
		if placed:
			queue.pending.erase(records[index])
			spawned.append(items[index])
		else:
			items[index].free()
	queue.retry_remaining = queue.placement.retry_seconds
	return spawned

## Получатель забрал вскрытый заказ: ожидающее содержимое не выпадает после успешного осмотра.
static func accept_contents(package: Entity) -> void:
	var identity: C_Package = package.get_component(C_Package) as C_Package
	var session: Entity = ECS.world.query.with_all([C_LootDrops]).execute_one()
	if identity == null or session == null:
		return
	var queue: C_LootDrops = session.get_component(C_LootDrops) as C_LootDrops
	var remaining: Array[PendingLootDrop] = []
	for record: PendingLootDrop in queue.pending:
		if record.package_id != identity.package_id:
			remaining.append(record)
	queue.pending.assign(remaining)

static func _single_item(item: Entity, require_inventory: bool) -> bool:
	var components: Array[Component] = item.component_resources.duplicate()
	for index: int in components.size():
		var inventory: C_InventoryItem = components[index] as C_InventoryItem
		if inventory == null:
			continue
		if inventory.definition == null or inventory.definition.key == &"":
			return false

		var single: C_InventoryItem = C_InventoryItem.new()
		single.definition = inventory.definition
		single.quantity = 1
		components[index] = single
		item.component_resources = components
		return true
	return not require_inventory
#endregion

#region Explicit recorded placement and registration
## Attempts one recorded placement and returns only the actual registered item; no retry clock or traversal.
static func place_pending(queue: C_LootDrops, record: PendingLootDrop) -> Entity:
	var item: Entity = _instantiate(record)
	if item == null:
		return null
	if not _place(queue, record, item):
		item.free()
		return null
	return item


static func _instantiate(record: PendingLootDrop) -> Entity:
	var scene: PackedScene = load(record.scene_path) as PackedScene
	if scene == null:
		return null
	var node: Node = scene.instantiate()
	var item: Entity = node as Entity
	if item == null or not node is RigidBody3D or not _single_item(item, false):
		node.free()
		return null
	return item

static func _place(queue: C_LootDrops, record: PendingLootDrop, item: Entity) -> bool:
	var parent: Node3D = ECS.world.get_parent() as Node3D
	var body: RigidBody3D = item as Node as RigidBody3D
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	if parent == null or body == null or not solver.prepare(body):
		return false

	var excluded: Array[RID] = [body.get_rid()]
	var source: Entity = ECS.world.entity_id_registry.get(record.source_id) as Entity
	var source_body: PhysicsBody3D = source as Node as PhysicsBody3D
	var path_excluded: Array[RID] = excluded.duplicate()
	if source_body != null:
		path_excluded.append(source_body.get_rid())
	if record.ignore_source and source_body != null:
		excluded.append(source_body.get_rid())
	var frame: int = Engine.get_physics_frames()
	if queue.reservation_frame != frame:
		queue.reservations.clear()
		queue.reservation_frame = frame

	var origin: Transform3D = Transform3D(body.transform.basis, record.origin)
	var result: ItemPlacementSolver.Result = solver.find(parent.get_world_3d().direct_space_state, origin, queue.placement, queue.reservations, excluded, record.airborne, record.anchor, path_excluded)
	if not result.available:
		return false

	var identity: C_PersistentIdentity = C_PersistentIdentity.new()
	identity.key = record.drop_id
	var components: Array[Component] = item.component_resources.duplicate()
	components.append(identity)
	item.component_resources = components
	item.id = record.drop_id

	# Позу задаём до входа в дерево: физический сервер впервые видит уже проверенную позицию.
	body.transform = parent.global_transform.affine_inverse() * result.pose
	parent.add_child(body)
	body.linear_velocity = record.velocity
	var context: EntitySpawnContext = EntityCompositionService.context_for(item, ECS.world,
		record.drop_id)
	if not EntityCompositionService.try_register(context, false):
		parent.remove_child(body)
		return false
	queue.reservations.append(result.bounds)
	_finish_context(record, item, source)
	return true

static func _finish_context(record: PendingLootDrop, item: Entity, source: Entity) -> void:
	var actor: Entity = ECS.world.entity_id_registry.get(record.actor_id) as Entity
	if record.activate_hazard:
		HazardEmitter.activate(item, actor, "", record.actor_id)

	if not record.package_id.is_empty() and EntityAvailability.contains(source, ECS.world):
		ECS.world.emit_event(PackageContentPlaced.EVENT, source, PackageContentPlaced.new(item, source))

	if not record.primary or record.package_id.is_empty():
		return

	if not record.opening_hazard_path.is_empty():
		var scene: PackedScene = load(record.opening_hazard_path) as PackedScene
		HazardEmitter.emit_scene(item, scene, "%s:opened:%s" % [record.package_id, record.opening_hazard_path], actor, record.package_id, record.actor_id)
	if EntityAvailability.contains(source, ECS.world):
		for effect: Entity in ECS.world.query.with_relationship([Relationship.new(R_HazardFollow.new(), source)]).execute().duplicate():
			var binding: Relationship = HazardFollowService.binding(effect)
			HazardFollowService.replace(effect, item, binding.relation as R_HazardFollow)
#endregion
