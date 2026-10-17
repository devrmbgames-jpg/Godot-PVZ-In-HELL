@tool
extends E_TraitedEntity
## Редактируемая физическая точка скупки; Area читает тела, расчёт остаётся у commerce owner.
class_name E_BuybackContainer


#region Физический состав и представление
## Возвращает снимок реальных пересекающихся Entities; пригодность и резервы проверяет сервис.
func bodies() -> Array[RigidBody3D]:
	var area: Area3D = get_node("ContentsArea") as Area3D
	var found: Array[RigidBody3D] = []
	for body: Node3D in area.get_overlapping_bodies():
		var rigid: RigidBody3D = body as RigidBody3D
		if rigid != null and rigid not in found and not is_ancestor_of(rigid):
			found.append(rigid)
	return found


## Сверяет полные native формы с авторским BoxShape при подтверждении, включая teleports в кадре.
## Одного прошлого Area overlap недостаточно: касание границы не становится предложением.
func contains(item: Entity) -> bool:
	var body: RigidBody3D = item as Node as RigidBody3D
	var collision: CollisionShape3D = get_node("ContentsArea/Collision") as CollisionShape3D
	var box: BoxShape3D = collision.shape as BoxShape3D
	assert(box != null, "Buyback ContentsArea requires an authored BoxShape3D")
	if body == null or collision.disabled:
		return false
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	if not solver.prepare(body):
		return false
	var bounds: AABB = solver.bounds_at(
		collision.global_transform.affine_inverse() * body.global_transform
	)
	return AABB(-box.size * 0.5, box.size).encloses(bounds)


## Обновляет только авторскую табличку; пересечение Area само по себе не продаёт вещи.
func show_message(message: String) -> void:
	(get_node("Sign") as Label3D).text = message
#endregion
