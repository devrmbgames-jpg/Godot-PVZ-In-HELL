extends RefCounted
## Read-only native camera clipping and solid ray queries; no NPC-facing vision cone approximation.
class_name NpcCameraVisibility


#region Actual player camera visibility
## Samples authored body points using the current player-owned camera and actual physics space.
static func observed(actor: E_DistrictNpc, player: Entity, rule: DEF_NpcGazeFreeze) -> bool:
	var observer: Node3D = player as Node as Node3D
	if observer == null or not actor.is_visible_in_tree():
		return false
	var camera: Camera3D = observer.get_viewport().get_camera_3d()
	if camera == null or not observer.is_ancestor_of(camera):
		return false
	var exclusions: Array[RID] = [actor.get_rid()]
	var observer_body: CollisionObject3D = observer as CollisionObject3D
	if observer_body != null:
		exclusions.append(observer_body.get_rid())
	for child: Node in observer.find_children("*", "CollisionObject3D", true, false):
		exclusions.append((child as CollisionObject3D).get_rid())
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray.from = camera.global_position
	ray.collision_mask = rule.visibility_mask
	ray.exclude = exclusions
	ray.hit_from_inside = true
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	for offset: Vector3 in rule.sample_offsets:
		var point: Vector3 = actor.to_global(offset)
		if not camera.is_position_in_frustum(point):
			continue
		ray.to = point
		if space.intersect_ray(ray).is_empty():
			return true
	return false
#endregion
