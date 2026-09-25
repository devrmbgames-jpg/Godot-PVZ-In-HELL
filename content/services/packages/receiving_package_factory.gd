extends RefCounted
## Package identity lookup, construction and spawn-space placement for Receiving.
class_name ReceivingPackageFactory

const SPAWN_MARGIN: float = 0.03


static func exists(package_id: String) -> bool:
	if not is_instance_valid(ECS.world):
		return false
	for existing: Entity in ECS.world.query.with_all([C_Package]).execute():
		var identity: C_Package = existing.get_component(C_Package) as C_Package
		if identity != null and identity.package_id == package_id:
			return true
	return false


static func create(
	zone: E_ReceivingZone,
	definition: DEF_Package,
	package_id: String,
	day_index: int,
	package_index: int,
) -> E_Package:
	if zone == null or definition == null or definition.scene_variants.is_empty():
		return null
	var package_scene_path: String = definition.scene_variants.pick_random()
	var packed: PackedScene = load(package_scene_path) as PackedScene
	if packed == null:
		return null
	var parcel: E_Package = packed.instantiate() as E_Package
	if parcel == null:
		return null
	var body: RigidBody3D = parcel as Node as RigidBody3D
	if body == null:
		parcel.free()
		return null

	parcel.package_id = package_id
	parcel.package_definition = definition
	parcel.name = "Parcel_%03d_%02d" % [day_index, package_index + 1]
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
		parcel.free()
		return null
	carry.throw_velocity = definition.throw_velocity
	parcel.component_resources = component_resources
	return parcel


static func try_place(zone: E_ReceivingZone, parcel: E_Package) -> bool:
	if zone == null or parcel == null:
		return false
	var body: RigidBody3D = parcel as Node as RigidBody3D
	var collision: CollisionShape3D = parcel.get_node("CollisionShape3D") as CollisionShape3D
	if body == null or collision == null or collision.shape == null:
		return false

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.margin = SPAWN_MARGIN
	query.collision_mask = body.collision_mask | body.collision_layer
	var zone_node: Node3D = zone as Node as Node3D
	var space: PhysicsDirectSpaceState3D = zone_node.get_world_3d().direct_space_state
	for child: Node in zone.spawn_points.get_children():
		var marker: Node3D = child as Node3D
		if marker == null:
			continue
		query.transform = marker.global_transform * collision.transform
		if not space.intersect_shape(query, 1).is_empty():
			continue
		zone.package_parent.add_child(parcel)
		body.global_transform = marker.global_transform
		ECS.world.add_entity(parcel, null, false)
		return true
	return false
