extends RefCounted
## Exact reach geometry for authored parcel box colliders; never moves the physical body.
class_name CustomerHandoffGeometry

## Automatic handover is strictly inside one metre; authored policies may reduce this distance.
const MAX_REACH_METERS: float = 1.0
const ORTHOGONALITY_EPSILON: float = 0.0001


#region Native parcel surface
## Returns the closest point on/in the active box volumes, or INF for unsupported geometry.
## Uses native shape-owner transforms, including offsets, rotation and orthogonal scale.
## Current authored parcel families use boxes; unsupported shapes never fall back to an AABB.
static func closest_point(body: PhysicsBody3D, origin: Vector3) -> Vector3:
	if body == null or not body.is_inside_tree() or not origin.is_finite():
		return Vector3(INF, INF, INF)
	var closest: Vector3 = Vector3(INF, INF, INF)
	var shortest_squared: float = INF
	for owner_id: int in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		var pose: Transform3D = body.global_transform * body.shape_owner_get_transform(owner_id)
		if not _valid_pose(pose):
			return Vector3(INF, INF, INF)
		for index: int in body.shape_owner_get_shape_count(owner_id):
			var shape: BoxShape3D = body.shape_owner_get_shape(owner_id, index) as BoxShape3D
			if shape == null:
				return Vector3(INF, INF, INF)
			var local_point: Vector3 = pose.affine_inverse() * origin
			var half_size: Vector3 = shape.size * 0.5
			var on_volume: Vector3 = pose * local_point.clamp(-half_size, half_size)
			var distance_squared: float = origin.distance_squared_to(on_volume)
			if distance_squared < shortest_squared:
				shortest_squared = distance_squared
				closest = on_volume
	return closest


static func _valid_pose(pose: Transform3D) -> bool:
	if not pose.is_finite() or is_zero_approx(pose.basis.determinant()):
		return false
	var right: Vector3 = pose.basis.x.normalized()
	var up: Vector3 = pose.basis.y.normalized()
	var back: Vector3 = pose.basis.z.normalized()
	# A sheared collision cannot use local axis clamping as an exact world-space projection.
	return (
		absf(right.dot(up)) <= ORTHOGONALITY_EPSILON
		and absf(right.dot(back)) <= ORTHOGONALITY_EPSILON
		and absf(up.dot(back)) <= ORTHOGONALITY_EPSILON
	)
#endregion
