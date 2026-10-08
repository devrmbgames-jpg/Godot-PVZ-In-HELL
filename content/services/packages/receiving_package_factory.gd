extends RefCounted
## Создаёт физическую коробку для приёмки и проверяет авторские точки размещения.
class_name ReceivingPackageFactory

const DEFAULT_PLACEMENT: DEF_ItemPlacement = preload("res://content/definitions/gameplay/deliveries/def_truck_cargo_placement.tres")


#region Создание экземпляра
## Проверяет наличие живой физической коробки с этим package_id.
static func exists(package_id: String) -> bool:
	return PackageQueries.find_live_package(package_id) != null


## Создаёт незарегистрированный экземпляр с собственными ID и параметрами переноски; размещение выполняется отдельно.
static func create(
	zone: E_ReceivingZone,
	definition: DEF_Package,
	package_id: String,
	day_index: int,
	package_index: int,
	physical_scene: String = "",
) -> E_Package:
	if zone == null or definition == null or definition.scene_variants.is_empty():
		return null

	if not physical_scene.is_empty() and physical_scene not in definition.scene_variants:
		return null
	var package_scene_path: String = physical_scene if not physical_scene.is_empty() else String(definition.scene_variants.pick_random())
	var packed: PackedScene = load(package_scene_path) as PackedScene
	if packed == null:
		return null

	var instance: Node = packed.instantiate()
	var parcel: E_Package = instance as E_Package
	if parcel == null:
		instance.free()
		return null

	var body: RigidBody3D = parcel as Node as RigidBody3D
	if body == null:
		parcel.free()
		return null

	if not configure_recipe(parcel, definition, package_id):
		parcel.free()
		return null
	parcel.name = "Parcel_%03d_%02d" % [day_index, package_index + 1]
	return parcel


## Materializes a prevalidated unregistered package recipe for delivery or snapshot reconstruction.
## Returns false for a prefab without a physical body or required carry configuration.
static func configure_recipe(parcel: E_Package, definition: DEF_Package, package_id: String) -> bool:
	var body: RigidBody3D = parcel as Node as RigidBody3D
	if body == null:
		return false
	parcel.package_id = package_id
	parcel.package_definition = definition
	body.mass = definition.mass_kg

	var component_resources: Array[Component] = parcel.component_resources.duplicate()
	var carry: C_Grabbable = null
	for component_index: int in component_resources.size():
		var component: Component = component_resources[component_index]
		if component is C_Grabbable:
			carry = component.duplicate() as C_Grabbable
			component_resources[component_index] = carry
			break
	if carry == null:
		return false

	carry.throw_velocity = definition.throw_velocity
	parcel.component_resources = component_resources
	return true


#endregion

#region Проверка и размещение
## Проверяет свободную авторскую точку, добавляет коробку в сцену и World; false оставляет её неразмещённой.
static func try_place(zone: E_ReceivingZone, parcel: E_Package) -> bool:
	if not is_instance_valid(zone) or not is_instance_valid(parcel) or not is_instance_valid(ECS.world):
		return false

	var body: RigidBody3D = parcel as Node as RigidBody3D
	var zone_node: Node3D = zone as Node as Node3D
	if body == null or zone_node == null or not is_instance_valid(zone.package_parent):
		return false
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	if not solver.prepare(body):
		return false

	var truck: E_MorningTruck = zone.get_truck()
	var policy: DEF_ItemPlacement = truck.placement if truck != null else DEFAULT_PLACEMENT
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	if receiving == null or policy == null:
		return false
	var frame: int = Engine.get_physics_frames()
	if receiving.reservation_frame != frame:
		receiving.reservation_frame = frame
		receiving.reservations.clear()

	var space: PhysicsDirectSpaceState3D = zone_node.get_world_3d().direct_space_state
	for marker: Marker3D in zone.get_cargo_markers():
		if not is_instance_valid(marker):
			continue
		var origin: Transform3D = marker.global_transform * Transform3D(body.transform.basis, Vector3.ZERO)
		var result: ItemPlacementSolver.Result = solver.find(space, origin, policy, receiving.reservations, [])
		if not result.available:
			continue

		# Единственная начальная поза устанавливается до передачи тела физическому движку.
		body.transform = zone.package_parent.global_transform.affine_inverse() * result.pose
		zone.package_parent.add_child(parcel)
		ECS.world.add_entity(parcel, null, false)
		receiving.reservations.append(result.bounds)
		return true
	return false
#endregion
