extends RefCounted
## Bounded native shape checks before enabling a retained NPC at a synchronization pose.
class_name NpcActivationSolver


#region Activation geometry
## Checks each active authored shape once, without moving the body or advancing its obligation.
static func available(body: E_DistrictNpc, position: Vector3) -> bool:
	if not position.is_finite():
		return false
	var pose: Transform3D = body.global_transform
	pose.origin = position
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.collision_mask = body.participation_collision_mask()
	query.exclude = [body.get_rid()]
	var checked_shapes: int = 0
	for owner_id: int in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		query.transform = pose * body.shape_owner_get_transform(owner_id)
		for shape_index: int in body.shape_owner_get_shape_count(owner_id):
			checked_shapes += 1
			query.shape = body.shape_owner_get_shape(owner_id, shape_index)
			if not space.intersect_shape(query, 1).is_empty():
				return false
	return checked_shapes > 0
#endregion
