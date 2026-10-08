extends RefCounted
## Определяет цель первого попадания луча без побочных эффектов представления.
class_name InteractionTargetingGeometry

const MAX_HELD_RECASTS: int = 3


#region Цели и физические родители
## Возвращает доступную сущность первого взаимодействия под лучом, иначе null.
static func find_target(holder: Entity, interactor: C_Interactor) -> Entity:
	return _interactable_entity(_raycast_collider(holder, interactor), holder)


## Возвращает первое физическое тело под лучом, в том числе без GECS-сущности.
static func find_physics_target(holder: Entity, interactor: C_Interactor) -> RigidBody3D:
	return collider_rigid_body(_raycast_collider(holder, interactor), holder)


## Поднимается по родителям коллайдера до ближайшей Entity.
static func collider_entity(collider: Object) -> Entity:
	var candidate_node: Node = collider as Node
	while candidate_node != null:
		if candidate_node is Entity:
			return candidate_node as Entity

		candidate_node = candidate_node.get_parent()
	return null


## Находит родительское RigidBody3D, исключая физическое тело holder, если задано.
static func collider_rigid_body(collider: Object, holder: Entity = null) -> RigidBody3D:
	var candidate_node: Node = collider as Node
	while candidate_node != null:
		var body: RigidBody3D = candidate_node as RigidBody3D
		if body != null:
			if is_instance_valid(holder) and body == (holder as Node as RigidBody3D):
				return null
			return body

		candidate_node = candidate_node.get_parent()
	return null


## Выбирает доступную игровую цель либо физический кандидат Carry для подсветки.
static func visual_target(holder: Entity, interactor: C_Interactor) -> Node:
	if interactor == null:
		return null
	if GrabService.entity_available(interactor.target):
		return interactor.target as Node
	if not is_instance_valid(interactor.physics_target):
		return null

	var physics_entity: Entity = collider_entity(interactor.physics_target)
	if physics_entity != null and not GrabService.entity_available(physics_entity):
		return null

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	return (
		interactor.physics_target
		if control != null and GrabService.is_carry_candidate(interactor.physics_target)
		else null
	)


#endregion

#region Авторитетный луч
static func _raycast_collider(holder: Entity, interactor: C_Interactor) -> Object:
	var interaction_raycast: RayCast3D = GrabService.interaction_raycast(holder)
	if (
		not is_instance_valid(interaction_raycast)
		or not interaction_raycast.is_inside_tree()
		or interactor == null
	):
		return null

	interaction_raycast.enabled = true
	# Объём площадки помогает наводиться с Carry; без груза луч видит саму посылку.
	interaction_raycast.collide_with_areas = GrabService.held_in_slot(holder, C_Grabbable.HoldSlot.CARRY) != null
	interaction_raycast.target_position = Vector3.FORWARD * maxf(
		interactor.interaction_distance,
		0.1,
	)
	interaction_raycast.collision_mask = interactor.collision_mask
	interaction_raycast.clear_exceptions()

	var holder_body: CollisionObject3D = holder as Node as CollisionObject3D
	if holder_body != null:
		interaction_raycast.add_exception_rid(holder_body.get_rid())
	for slot_index: int in 3:
		var held: Entity = GrabService.held_in_slot(holder, slot_index)
		var held_body: CollisionObject3D = PhysicsGrabTarget.body_for(held)
		if held_body != null:
			interaction_raycast.add_exception_rid(held_body.get_rid())

	interaction_raycast.force_raycast_update()
	for _attempt: int in MAX_HELD_RECASTS + 1:
		if not interaction_raycast.is_colliding():
			return null

		var collider: Object = interaction_raycast.get_collider()
		var collider_body: RigidBody3D = collider_rigid_body(collider)
		if collider_body == null or not _body_is_held_by(collider_body, holder):
			return collider

		interaction_raycast.add_exception_rid(collider_body.get_rid())
		interaction_raycast.force_raycast_update()
	return null


static func _interactable_entity(collider: Object, holder: Entity) -> Entity:
	var candidate: Entity = collider_entity(collider)
	if not is_instance_valid(candidate) or candidate == holder or not candidate.enabled:
		return null

	var interactable: C_Interactable = candidate.get_component(C_Interactable) as C_Interactable
	return candidate if interactable != null and interactable.enabled else null


static func _body_is_held_by(body: RigidBody3D, holder: Entity) -> bool:
	if not is_instance_valid(body) or not is_instance_valid(holder):
		return false

	var handle: Entity = PhysicsGrabTarget.handle_for(body, false)
	var grip: Relationship = GrabService.held_relationship(handle)
	return grip != null and grip.target == holder

#endregion
