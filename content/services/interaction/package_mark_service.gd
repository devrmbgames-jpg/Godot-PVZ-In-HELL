extends RefCounted
## Owns package ink data mutation and package-local surface conversion.
class_name PackageMarkService

const SURFACE_OFFSET: float = 0.004
const SAME_FACE_DOT: float = 0.995
const MAX_SAMPLE_GAP: float = 0.12


static func append_sample(
	marker: C_Marker,
	parcel: Entity,
	world_point: Vector3,
	world_normal: Vector3,
) -> void:
	if not drawable(parcel):
		break_stroke(marker)
		return
	var marks: C_PackageMarks = parcel.get_component(C_PackageMarks) as C_PackageMarks
	if marks == null or marks.point_count >= marker.max_package_points:
		break_stroke(marker)
		return

	var body: Node3D = parcel as Node as Node3D
	if body == null:
		break_stroke(marker)
		return
	var local_normal: Vector3 = (body.global_basis.transposed() * world_normal).normalized()
	var point: Vector3 = body.to_local(world_point + world_normal * SURFACE_OFFSET)
	var package_entity: E_Package = parcel as E_Package
	if package_entity != null and is_instance_valid(package_entity.marking_surface):
		point = _visual_surface_point(
			package_entity.marking_surface,
			body,
			world_point,
			world_normal,
		)

	var continuing: bool = marker.parcel == parcel and marker.stroke != null
	if continuing:
		var previous: Vector3 = marker.stroke.points[-1]
		continuing = marker.stroke.normal.dot(local_normal) >= SAME_FACE_DOT
		continuing = continuing and previous.distance_to(point) <= MAX_SAMPLE_GAP
		if continuing and previous.distance_to(point) < marker.sample_spacing:
			return

	if not continuing:
		marker.stroke = PackageMarkStroke.new()
		marker.stroke.normal = local_normal
		marker.stroke.width = marker.ink_width
		marker.stroke.color = marker.ink_color
		marker.parcel = parcel
		marks.strokes.append(marker.stroke)

	marker.stroke.points.append(point)
	marks.point_count += 1
	marks.revision += 1


static func break_stroke(marker: C_Marker) -> void:
	if marker == null:
		return
	marker.parcel = null
	marker.stroke = null


static func clear_marks(parcel: Entity) -> void:
	if not is_instance_valid(parcel):
		return
	var marks: C_PackageMarks = parcel.get_component(C_PackageMarks) as C_PackageMarks
	if marks != null and marks.point_count > 0:
		marks.strokes.clear()
		marks.point_count = 0
		marks.revision += 1


static func drawable(parcel: Entity) -> bool:
	if not GrabService.entity_available(parcel) or not parcel.has_component(C_PackageMarks):
		return false
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	return (
		state != null and state.damage != C_PackageState.Damage.DESTROYED
		and state.registration != C_PackageState.Registration.DELIVERED
	)


static func _visual_surface_point(
	surface: MeshInstance3D,
	body: Node3D,
	world_point: Vector3,
	world_normal: Vector3,
) -> Vector3:
	var normal: Vector3 = (surface.global_basis.transposed() * world_normal).normalized()
	var point: Vector3 = surface.to_local(world_point)
	var bounds: AABB = surface.mesh.get_aabb()
	var axis: int = normal.abs().max_axis_index()
	var positive: bool = normal[axis] > 0.0
	point[axis] = bounds.end[axis] if positive else bounds.position[axis]
	point[axis] += SURFACE_OFFSET if positive else -SURFACE_OFFSET
	return body.to_local(surface.to_global(point))
