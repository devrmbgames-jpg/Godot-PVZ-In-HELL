extends RefCounted
## Геометрия фактической позы и первого физического препятствия, отдельно от намерения ввода.
class_name CombatGeometry

const GENERIC_TARGET_HEIGHT: float = 0.2


## Возвращает мировую позицию головы персонажа либо тела для начала луча.
static func origin(actor: Entity) -> Vector3:
	var character: E_PhysicalCharacter = actor as E_PhysicalCharacter
	if character != null and character.head_axis_x != null:
		return character.head_axis_x.global_position

	var node: Node3D = actor as Node as Node3D
	return node.global_position if node != null else Vector3.ZERO


## Читает фактическое направление головы/тела, без намерения ввода.
static func forward(actor: Entity) -> Vector3:
	var character: E_PhysicalCharacter = actor as E_PhysicalCharacter
	if character != null and character.head_axis_x != null:
		return -character.head_axis_x.global_basis.z.normalized()

	var node: Node3D = actor as Node as Node3D
	return -node.global_basis.z.normalized() if node != null else Vector3.FORWARD


## Возвращает мировую боевую точку персонажа, двери или предмета.
static func aim_point(target: Entity) -> Vector3:
	var node: Node3D = target as Node as Node3D
	var character: E_PhysicalCharacter = target as E_PhysicalCharacter
	if character != null and character.head_axis_x != null:
		return node.global_position.lerp(character.head_axis_x.global_position, 0.5)

	var door: E_Door = target as E_Door
	if door != null:
		return door.strike_point()
	return node.global_position + Vector3.UP * GENERIC_TARGET_HEIGHT


## Исключает тело атакующего и удерживаемые им физические предметы из его луча.
static func exclusions(actor: Entity) -> Array[RID]:
	var result: Array[RID] = []
	var body: PhysicsBody3D = actor as Node as PhysicsBody3D
	if body != null:
		result.append(body.get_rid())
	for slot: int in 3:
		var held: Entity = GrabService.held_in_slot(actor, slot)
		var held_body: RigidBody3D = GrabService.physical_body(held)
		if held_body != null:
			result.append(held_body.get_rid())
	return result


## Проверяет первое физическое препятствие; пустой луч либо попадание в цель разрешают атаку.
static func clear_line(actor: Entity, target: Entity, mask: int) -> bool:
	var node: Node3D = actor as Node as Node3D
	if node == null or not node.is_inside_tree() or not is_instance_valid(target):
		return false

	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin(actor), aim_point(target), mask, exclusions(actor))
	var hit: Dictionary = node.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or InteractionTargetingGeometry.collider_entity(hit.get("collider") as Object) == target


## Проверяет дальность в метрах и половину угла сектора в градусах.
static func in_cone(actor: Entity, target: Entity, reach: float, half_angle_degrees: float) -> bool:
	if not is_instance_valid(target) or not (target as Node) is Node3D:
		return false

	var direction: Vector3 = aim_point(target) - origin(actor)
	return direction.length() <= reach and forward(actor).dot(direction.normalized()) >= cos(deg_to_rad(half_angle_degrees))
