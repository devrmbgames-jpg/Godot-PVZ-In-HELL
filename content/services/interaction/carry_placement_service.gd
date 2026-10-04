extends RefCounted
## Проверяет занятость и полный путь размещения перед освобождением Carry.
class_name CarryPlacementService


#region Проверка и размещение Carry
## Проверяет фильтр, дистанцию, занятость и путь к площадке до изменения хвата.
static func can_place(actor: Entity, area: E_PlacementArea) -> bool:
	if (
		not GrabService.holder_available(actor) or not GrabService.entity_available(area)
		or not is_instance_valid(area.anchor)
		or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.CARRY
		or not GrabService.within_pickup_reach(actor, area)
	):
		return false

	var config: C_PlacementArea = area.get_component(C_PlacementArea) as C_PlacementArea
	var item: Entity = GrabService.held_in_slot(actor, C_Grabbable.HoldSlot.CARRY)
	if config == null or not GrabService.entity_available(item):
		return false
	if config.filter != null and not ItemAccessService.matches(item.get_component(C_AccessItem) as C_AccessItem, config.filter):
		return false

	var body: RigidBody3D = GrabService.physical_body(item)
	if body == null or body.freeze or not config.volume_size.is_finite():
		return false
	if config.volume_size.x <= 0.0 or config.volume_size.y <= 0.0 or config.volume_size.z <= 0.0:
		return false

	var excluded: Array[RID] = [body.get_rid()]
	var actor_body: CollisionObject3D = actor as Node as CollisionObject3D
	var area_body: CollisionObject3D = area as Node as CollisionObject3D
	if actor_body != null:
		excluded.append(actor_body.get_rid())
	if area_body != null:
		excluded.append(area_body.get_rid())
	var volume: BoxShape3D = BoxShape3D.new()
	volume.size = config.volume_size

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = volume
	query.transform = area.anchor.global_transform
	query.collision_mask = config.collision_mask
	query.exclude = excluded
	if not body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	return _clear_path(body, area.anchor.global_transform, excluded, config.collision_mask | body.collision_mask, config.clearance_margin)


## Перед полкой можно выровнять посылку по высоте, затем задвинуть её внутрь.
## Каждый сегмент проверяется до отпускания; обход стен и занятых мест не допускается.
static func _clear_path(body: RigidBody3D, destination: Transform3D, excluded: Array[RID], mask: int, margin: float) -> bool:
	if BodyPlacementQuery.clear_path(body, destination, excluded, mask, margin):
		return true

	var start: Transform3D = body.global_transform
	var oriented: Transform3D = Transform3D(destination.basis, start.origin)
	var aligned: Transform3D = oriented
	aligned.origin.y = destination.origin.y
	return (
		BodyPlacementQuery.clear_path_from(body, start, oriented, excluded, mask, margin)
		and BodyPlacementQuery.clear_path_from(body, oriented, aligned, excluded, mask, margin)
		and BodyPlacementQuery.clear_path_from(body, aligned, destination, excluded, mask, margin)
	)


## Повторно проверяет размещение, освобождает хват и однократно ставит тело в точку площадки.
static func place(actor: Entity, area: E_PlacementArea) -> bool:
	if not can_place(actor, area):
		return false

	var item: Entity = GrabService.held_in_slot(actor, C_Grabbable.HoldSlot.CARRY)
	var body: RigidBody3D = GrabService.physical_body(item)
	var destination: Transform3D = area.anchor.global_transform
	GrabService.release(actor, item)
	ThrowContext.cancel(item)
	body.global_transform = destination
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false
	return true

#endregion
