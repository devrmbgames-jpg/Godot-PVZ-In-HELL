extends RefCounted
## Exact endpoint overlaps + swept shape checks. Rotation uses a conservative
## enclosing sphere so unsampled intermediate orientations cannot tunnel.
class_name BodyPlacementQuery

const ROTATION_EPSILON: float = 0.001


static func clear_path(body: RigidBody3D, destination: Transform3D, excluded: Array[RID], mask: int, margin: float) -> bool:
	if not is_instance_valid(body) or not body.is_inside_tree() or not destination.is_finite():
		return false
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var moving_rotation: bool = not body.global_basis.is_equal_approx(destination.basis)
	var count: int = 0
	var radius: float = 0.0
	for owner_id: int in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		var local: Transform3D = body.shape_owner_get_transform(owner_id)
		for index: int in body.shape_owner_get_shape_count(owner_id):
			var shape: Shape3D = body.shape_owner_get_shape(owner_id, index)
			# Rigid moving bodies must provide bounded convex collision shapes.
			if shape == null or shape is ConcavePolygonShape3D or shape is WorldBoundaryShape3D:
				return false
			count += 1
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = destination * local
			query.exclude = excluded
			query.collision_mask = mask
			query.margin = margin
			if not space.intersect_shape(query, 1).is_empty():
				return false
			query.transform = body.global_transform * local
			if not space.intersect_shape(query, 1).is_empty():
				return false
			if not moving_rotation:
				query.motion = destination.origin - body.global_position
				var fractions: PackedFloat32Array = space.cast_motion(query)
				if fractions.size() != 2 or fractions[0] < 1.0:
					return false
			else:
				var bounds: AABB = shape.get_debug_mesh().get_aabb()
				for corner: int in 8:
					var offset: Vector3 = local * bounds.get_endpoint(corner)
					radius = maxf(radius, (body.global_basis * offset).length())
					radius = maxf(radius, (destination.basis * offset).length())
	if count == 0:
		return false
	if moving_rotation:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = maxf(radius, ROTATION_EPSILON)
		var sweep: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		sweep.shape = sphere
		sweep.transform = Transform3D(Basis.IDENTITY, body.global_position)
		sweep.exclude = excluded
		sweep.collision_mask = mask
		sweep.margin = margin
		if not space.intersect_shape(sweep, 1).is_empty():
			return false
		sweep.motion = destination.origin - body.global_position
		var fractions: PackedFloat32Array = space.cast_motion(sweep)
		if fractions.size() != 2 or fractions[0] < 1.0:
			return false
		sweep.motion = Vector3.ZERO
		sweep.transform.origin = destination.origin
		if not space.intersect_shape(sweep, 1).is_empty():
			return false
	return true
