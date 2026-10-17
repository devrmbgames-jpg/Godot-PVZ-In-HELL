@tool
extends E_TraitedEntity
## Native ящик и место стенной подсказки; расход/сроки/выдача принадлежат commerce.
class_name E_CraftingContainer


#region Native состав и геометрия
## Возвращает снимок реальных тел, не перемещая их и не передавая автоматически.
func bodies() -> Array[RigidBody3D]:
	var area: Area3D = get_node("ContentsArea") as Area3D
	var found: Array[RigidBody3D] = []
	for body: Node3D in area.get_overlapping_bodies():
		var rigid: RigidBody3D = body as RigidBody3D
		if rigid != null and rigid not in found and not is_ancestor_of(rigid):
			found.append(rigid)
	return found


## Сверяет фактические формы с полным объёмом ящика, включая перенос в текущем кадре.
func contains(item: Entity) -> bool:
	var body: RigidBody3D = item as Node as RigidBody3D
	if body == null:
		return false
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	return solver.prepare(body) and encloses(body.global_transform, solver)


## Проверяет подготовленную позу без регистрации/изменения физического тела.
func encloses(pose: Transform3D, solver: ItemPlacementSolver) -> bool:
	var collision: CollisionShape3D = get_node("ContentsArea/Collision") as CollisionShape3D
	var box: BoxShape3D = collision.shape as BoxShape3D
	assert(box != null)
	return (
		not collision.disabled
		and AABB(-box.size * 0.5, box.size).encloses(
			solver.bounds_at(collision.global_transform.affine_inverse() * pose),
		)
	)


## Проекция авторских меток, без второго mutable состояния подсказки.
func show_state(message: String, hint: String) -> void:
	(get_node("Sign") as Label3D).text = message
	(get_node("HintWall/Text") as Label3D).text = hint
#endregion
