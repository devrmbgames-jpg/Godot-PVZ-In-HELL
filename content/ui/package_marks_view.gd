extends MeshInstance3D
## Renders package-owned local ink; never decides where drawing is allowed.
class_name PackageMarksView

var _revision: int = -1


func _process(_delta: float) -> void:
	var parcel: Entity = get_parent() as Entity
	var marks: C_PackageMarks = parcel.get_component(C_PackageMarks) as C_PackageMarks
	if marks == null or _revision == marks.revision:
		return

	_revision = marks.revision
	if marks.point_count == 0:
		mesh = null
		return

	var ink: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ink.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)

	for stroke: PackageMarkStroke in marks.strokes:
		ink.surface_set_color(stroke.color)
		var tangent: Vector3 = stroke.normal.cross(Vector3.UP).normalized()
		if tangent.is_zero_approx():
			tangent = stroke.normal.cross(Vector3.RIGHT).normalized()
		var half_width: float = stroke.width * 0.5
		var along: Vector3 = tangent * half_width
		var across: Vector3 = stroke.normal.cross(tangent) * half_width
		for point_index: int in stroke.points.size():
			var point: Vector3 = stroke.points[point_index]
			_quad(
				ink,
				point - along - across,
				point + along - across,
				point + along + across,
				point - along + across,
			)
			if point_index > 0:
				var previous: Vector3 = stroke.points[point_index - 1]
				var side: Vector3 = stroke.normal.cross(point - previous).normalized() * half_width
				_quad(ink, previous - side, point - side, point + side, previous + side)

	ink.surface_end()
	mesh = ink


func _quad(
	ink: ImmediateMesh,
	first: Vector3,
	second: Vector3,
	third: Vector3,
	fourth: Vector3,
) -> void:
	for vertex: Vector3 in [first, second, third, first, third, fourth]:
		ink.surface_add_vertex(vertex)
