extends RefCounted
## Samples the first drawable package under the marker's virtual viewport pointer.
class_name MarkerSurfaceSampler


static func sample(tool: Entity, actor: Entity, marker: C_Marker) -> MarkerSurfaceSample:
	if not is_instance_valid(tool) or not is_instance_valid(actor) or marker == null:
		return null
	var viewport: Viewport = (actor as Node).get_viewport()
	var camera: Camera3D = viewport.get_camera_3d()
	if camera == null:
		return null

	var origin: Vector3 = camera.project_ray_origin(marker.pointer)
	var direction: Vector3 = camera.project_ray_normal(marker.pointer)
	var destination: Vector3 = origin + direction * marker.drawing_range
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	if interactor == null:
		return null
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		destination,
		interactor.collision_mask,
	)
	var excluded: Array[RID] = []
	var actor_body: CollisionObject3D = actor as Node as CollisionObject3D
	if actor_body != null:
		excluded.append(actor_body.get_rid())
	var tool_body: CollisionObject3D = tool as Node as CollisionObject3D
	if tool_body != null:
		excluded.append(tool_body.get_rid())
	ray_query.exclude = excluded

	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(ray_query)
	if hit.is_empty():
		return null
	var parcel: Entity = InteractionTargetingService.collider_entity(hit["collider"] as Object)
	if not PackageMarkService.drawable(parcel):
		return null

	var result: MarkerSurfaceSample = MarkerSurfaceSample.new()
	result.parcel = parcel
	result.world_point = hit["position"] as Vector3
	result.world_normal = hit["normal"] as Vector3
	return result
