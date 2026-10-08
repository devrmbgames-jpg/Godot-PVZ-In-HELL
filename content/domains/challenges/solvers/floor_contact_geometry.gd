extends RefCounted
## Measures authored floor surface bounds against the body's committed physical support contact.
class_name FloorContactGeometry

#region Physical contact measurement
## Checks real support RID, local authored bounds and height tolerance without advancing time.
static func touches_surface(motion: C_Motion, pose: Transform3D, profile: DEF_FloorHazard) -> bool:
	if motion == null or not motion.is_on_floor or not motion.floor_body_rid.is_valid():
		return false

	var point: Vector3 = pose.affine_inverse() * motion.floor_contact_position
	return (
		absf(point.x) <= profile.size.x * 0.5
		and absf(point.z) <= profile.size.y * 0.5
		and absf(point.y) <= profile.contact_tolerance
	)


#endregion
