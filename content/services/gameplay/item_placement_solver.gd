extends RefCounted
## Ограниченная проверка опоры и всех форм тела без перемещения и регистрации prefab.
class_name ItemPlacementSolver

class Result extends RefCounted:
	## Найдена доступная позиция.
	var available: bool = false
	## Проверенная мировая поза тела.
	var pose: Transform3D = Transform3D.IDENTITY
	## Консервативная граница для резерва партии до обновления physics space.
	var bounds: AABB = AABB()
	## Число проверенных авторских позиций для диагностики ограниченного перебора.
	var attempts: int = 0

class ShapePart extends RefCounted:
	## Реальная форма твёрдого тела.
	var shape: Shape3D
	## Трансформация формы относительно корня prefab.
	var local_pose: Transform3D

var _parts: Array[ShapePart] = []
var _bounds: AABB = AABB()

#region Подготовка форм
## Снимает активные ограниченные формы, учитывая вложенные трансформации и исключая Area.
func prepare(body: PhysicsBody3D) -> bool:
	_parts.clear()
	_collect(body, body, Transform3D.IDENTITY)
	if _parts.is_empty():
		return false

	var first: bool = true
	for part: ShapePart in _parts:
		if part.shape is ConcavePolygonShape3D or part.shape is WorldBoundaryShape3D:
			_parts.clear()
			return false
		var bounds: AABB = part.local_pose * part.shape.get_debug_mesh().get_aabb()
		_bounds = bounds if first else _bounds.merge(bounds)
		first = false
	return _bounds.size.length_squared() > 0.0

## Возвращает границы подготовленной составной формы в указанной позе.
func bounds_at(pose: Transform3D) -> AABB:
	return pose * _bounds

func _collect(root: Node, node: Node, local_pose: Transform3D) -> void:
	if node != root and node is CollisionObject3D:
		return
	var shape_node: CollisionShape3D = node as CollisionShape3D
	if shape_node != null and not shape_node.disabled and shape_node.shape != null:
		var part: ShapePart = ShapePart.new()
		part.shape = shape_node.shape
		part.local_pose = local_pose
		_parts.append(part)

	for child: Node in node.get_children():
		var spatial: Node3D = child as Node3D
		var child_pose: Transform3D = local_pose * spatial.transform if spatial != null else local_pose
		_collect(root, child, child_pose)
#endregion

#region Ограниченное размещение
## Проверяет первые 16 смещений; резервы исключают пересечение тел одной партии в том же кадре.
func find(
	space: PhysicsDirectSpaceState3D,
	origin: Transform3D,
	definition: DEF_ItemPlacement,
	reservations: Array[AABB],
	excluded: Array[RID],
	airborne: bool = false,
	anchor: Vector3 = Vector3(INF, INF, INF),
	path_excluded: Array[RID] = [],
) -> Result:
	var result: Result = Result.new()
	if space == null or definition == null or _parts.is_empty():
		return result

	var projected: AABB = Transform3D(origin.basis, Vector3.ZERO) * _bounds
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray.collision_mask = definition.support_mask
	ray.exclude = path_excluded if not path_excluded.is_empty() else excluded
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.collision_mask = definition.obstacle_mask
	query.margin = definition.margin
	query.exclude = excluded
	var path_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	path_ray.collision_mask = definition.obstacle_mask
	path_ray.exclude = path_excluded if not path_excluded.is_empty() else excluded
	var source_position: Vector3 = anchor if anchor.is_finite() else origin.origin

	for index: int in mini(definition.offsets.size(), DEF_ItemPlacement.MAX_CANDIDATES):
		result.attempts += 1
		var pose: Transform3D = origin
		pose.origin += origin.basis * definition.offsets[index] if definition.local_offsets else definition.offsets[index]
		var support: Vector2 = _support(space, ray, pose.origin, projected, definition)
		if not is_finite(support.x):
			continue
		var floor_y: float = support.x - projected.position.y + definition.clearance
		pose.origin.y = maxf(pose.origin.y, floor_y) if airborne else floor_y
		var bounds: AABB = bounds_at(pose).grow(definition.margin)
		if _reserved(bounds, reservations) or not _clear(space, query, pose):
			continue
		var path_height: float = maxf(source_position.y, bounds.get_center().y) + definition.clearance
		path_ray.from = Vector3(source_position.x, path_height, source_position.z)
		path_ray.to = Vector3(bounds.get_center().x, path_height, bounds.get_center().z)
		if definition.require_clear_path and not path_ray.from.is_equal_approx(path_ray.to) and not space.intersect_ray(path_ray).is_empty():
			continue

		result.available = true
		result.pose = pose
		result.bounds = bounds
		return result
	return result

func _support(space: PhysicsDirectSpaceState3D, ray: PhysicsRayQueryParameters3D, position: Vector3, bounds: AABB, definition: DEF_ItemPlacement) -> Vector2:
	var center: Vector3 = bounds.get_center()
	var probes: Array[Vector2] = [Vector2(center.x, center.z), Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.end.x, bounds.position.z), Vector2(bounds.position.x, bounds.end.z), Vector2(bounds.end.x, bounds.end.z)]
	var highest: float = -INF
	var lowest: float = INF
	for probe: Vector2 in probes:
		ray.from = position + Vector3(probe.x, definition.probe_rise, probe.y)
		ray.to = ray.from + Vector3.DOWN * definition.probe_depth
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector3).y < definition.support_normal:
			return Vector2(INF, INF)
		var height: float = (hit.position as Vector3).y
		highest = maxf(highest, height)
		lowest = minf(lowest, height)
	return Vector2(highest, lowest) if highest - lowest <= definition.support_variation else Vector2(INF, INF)

func _clear(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, pose: Transform3D) -> bool:
	for part: ShapePart in _parts:
		query.shape = part.shape
		query.transform = pose * part.local_pose
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true

func _reserved(bounds: AABB, reservations: Array[AABB]) -> bool:
	for reserved: AABB in reservations:
		if bounds.intersects(reserved):
			return true
	return false
#endregion
