extends RefCounted
## Exact reach geometry for authored parcel box colliders; never moves the physical body.
class_name CustomerHandoffGeometry

## Automatic handover is strictly inside one metre; authored policies may reduce this distance.
const MAX_REACH_METERS: float = 1.0
const ORTHOGONALITY_EPSILON: float = 0.0001
const SUPPORT_MIN_UP_NORMAL: float = 0.7


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


#region Native counter support
## Chooses a lateral path clear for every actual parcel collider over one metre of travel.
## Blocked sides return zero, so a holy rejection never invents a teleport or an aimed hit.
static func clear_side_direction(
	body: RigidBody3D, to_player: Vector3, customer: Entity, actor: Entity,
) -> Vector3:
	var away: Vector3 = to_player.slide(Vector3.UP).normalized()
	if away.is_zero_approx():
		away = Vector3.FORWARD
	var side: Vector3 = away.cross(Vector3.UP).normalized()
	var excluded: Array[RID] = [body.get_rid()]
	for owner: Entity in [customer, actor]:
		var physics: PhysicsBody3D = owner as Node as PhysicsBody3D
		if physics != null:
			excluded.append(physics.get_rid())
	for direction: Vector3 in [side, -side]:
		var clear: bool = true
		for owner_id: int in body.get_shape_owners():
			if body.is_shape_owner_disabled(owner_id):
				continue
			for index: int in body.shape_owner_get_shape_count(owner_id):
				var parameters: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
				parameters.shape = body.shape_owner_get_shape(owner_id, index)
				parameters.transform = (
					body.global_transform * body.shape_owner_get_transform(owner_id)
				)
				parameters.motion = direction * MAX_REACH_METERS
				parameters.collision_mask = CustomerHandoffService.OCCLUSION_MASK
				parameters.exclude = excluded
				var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
				var travel: PackedFloat32Array = space.cast_motion(parameters)
				if travel.size() != 2 or travel[0] < 1.0:
					clear = false
		if clear:
			return direction
	return Vector3.ZERO


## Reads a downward physical support chain through the supplied stable parcels to the counter.
## The caller filters hands/slots/cargo and velocities; the chain is bounded by this finite set.
static func counter_supported(
	counter: PhysicsBody3D, parcel: RigidBody3D, stable: Array[RigidBody3D], tolerance: float,
	mask: int,
) -> bool:
	var space: PhysicsDirectSpaceState3D = counter.get_world_3d().direct_space_state
	var current: RigidBody3D = parcel
	var excluded: Array[RID] = []
	for depth: int in stable.size() + 1:
		if excluded.has(current.get_rid()):
			return false
		excluded.append(current.get_rid())
		var bounds: AABB = _box_bounds(current)
		if not bounds.size.is_finite() or bounds.size.length_squared() <= 0.0:
			return false
		var bottom: Vector3 = Vector3(
			bounds.get_center().x, bounds.position.y, bounds.get_center().z,
		)
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			bounds.get_center(), bottom - Vector3.UP * tolerance,
			mask, excluded,
		)
		# Jolt's resting contact can slightly penetrate the authored box volume.
		# Start inside the excluded parcel, above the contact, to read its real upward normal.
		ray.hit_from_inside = true
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty():
			return false
		var normal: Vector3 = hit.normal
		if normal.dot(Vector3.UP) < SUPPORT_MIN_UP_NORMAL:
			return false
		if hit.collider == counter:
			return true
		var support: RigidBody3D = hit.collider as RigidBody3D
		if support == null or not stable.has(support):
			return false
		current = support
	return false


static func _box_bounds(body: RigidBody3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for owner_id: int in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		var pose: Transform3D = body.global_transform * body.shape_owner_get_transform(owner_id)
		if not _valid_pose(pose):
			return AABB()
		for index: int in body.shape_owner_get_shape_count(owner_id):
			var shape: BoxShape3D = body.shape_owner_get_shape(owner_id, index) as BoxShape3D
			if shape == null:
				return AABB()
			var bounds: AABB = pose * AABB(-shape.size * 0.5, shape.size)
			result = bounds if first else result.merge(bounds)
			first = false
	return result
#endregion
