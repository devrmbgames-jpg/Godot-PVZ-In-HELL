extends RefCounted
## Одна явная попытка materialize обещанное изделие в проверенной позе внутри native ящика.
class_name CraftingOutputService


#region Физическая выдача одного устойчивого результата
## Занятость оставляет emitted=false. Регистрация под общим guard запрещает частичный snapshot.
static func place(
	container: E_CraftingContainer,
	state: C_Crafting,
	output: CraftingOutput,
) -> bool:
	var world: World = ECS.world
	var commerce: C_Commerce = CommerceService.current()
	if commerce == null or commerce.transaction_in_progress or output.emitted:
		return false
	if world.entity_id_registry.has(output.entity_id):
		return false
	var scene: PackedScene = load(output.definition.world_pickup_scene) as PackedScene
	if scene == null:
		return false
	var item: Entity = scene.instantiate() as Entity
	var body: RigidBody3D = item as Node as RigidBody3D
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	if body == null or not solver.prepare(body):
		if is_instance_valid(item):
			item.free()
		return false
	var frame: int = Engine.get_physics_frames()
	if state.reservation_frame != frame:
		state.reservations.clear()
		state.reservation_frame = frame
	var marker: Marker3D = container.get_node("Output") as Marker3D
	var pose: ItemPlacementSolver.Result = solver.find(
		container.get_world_3d().direct_space_state,
		marker.global_transform,
		state.profile.placement,
		state.reservations,
		[body.get_rid()],
	)
	if not pose.available or not container.encloses(pose.pose, solver):
		item.free()
		return false
	var identity: C_PersistentIdentity = C_PersistentIdentity.new()
	identity.key = output.entity_id
	var components: Array[Component] = item.component_resources.duplicate()
	components.append(identity)
	for index: int in components.size():
		var authored: C_InventoryItem = components[index] as C_InventoryItem
		if authored == null:
			continue
		var stack: C_InventoryItem = authored.duplicate() as C_InventoryItem
		stack.quantity = 1
		components[index] = stack
	item.component_resources = components
	item.id = output.entity_id
	var parent: Node3D = world.get_parent() as Node3D
	body.transform = parent.global_transform.affine_inverse() * pose.pose
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		item,
		world,
		output.entity_id,
	)
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
	if not plan.valid():
		item.free()
		return false
	commerce.transaction_in_progress = true
	output.emitted = true
	var registered: bool = EntityCompositionService.register_plan(context, plan)
	if registered:
		state.reservations.append(pose.bounds)
	else:
		output.emitted = false
		item.free()
	commerce.transaction_in_progress = false
	return registered
#endregion
