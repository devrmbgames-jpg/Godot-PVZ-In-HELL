extends RefCounted
## First-hit gameplay target resolution with no presentation side effects.
class_name InteractionTargetingService


static func find_target(holder: Entity, interactor: C_Interactor) -> Entity:
	return _interactable_entity(_raycast_collider(holder, interactor), holder)


static func find_physics_target(holder: Entity, interactor: C_Interactor) -> RigidBody3D:
	return collider_rigid_body(_raycast_collider(holder, interactor), holder)


static func collider_entity(collider: Object) -> Entity:
	var candidate_node: Node = collider as Node
	while candidate_node != null:
		if candidate_node is Entity:
			return candidate_node as Entity
		candidate_node = candidate_node.get_parent()
	return null


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


static func visual_target(holder: Entity, interactor: C_Interactor) -> Node:
	if interactor == null:
		return null
	if is_instance_valid(interactor.target):
		return interactor.target as Node
	if not is_instance_valid(interactor.physics_target):
		return null
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	return (
		interactor.physics_target
		if control != null and control.is_carry_candidate(interactor.physics_target)
		else null
	)


static func _raycast_collider(holder: Entity, interactor: C_Interactor) -> Object:
	var interaction_raycast: RayCast3D = GrabService.interaction_raycast(holder)
	if (
		not is_instance_valid(interaction_raycast)
		or not interaction_raycast.is_inside_tree()
		or interactor == null
	):
		return null

	interaction_raycast.enabled = true
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
	return interaction_raycast.get_collider() if interaction_raycast.is_colliding() else null


static func _interactable_entity(collider: Object, holder: Entity) -> Entity:
	var candidate: Entity = collider_entity(collider)
	if not is_instance_valid(candidate) or candidate == holder or not candidate.enabled:
		return null
	var interactable: C_Interactable = candidate.get_component(C_Interactable) as C_Interactable
	return candidate if interactable != null and interactable.enabled else null
