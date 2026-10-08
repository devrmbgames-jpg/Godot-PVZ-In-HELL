extends RefCounted
## Повторно проверяет текущую цель луча и допустимую дистанцию подбора.
class_name GrabReachQueries

#region Operations
## Повторно проверяет первое попадание луча и общий предел дистанции взаимодействия.
## Игровая цель может быть CharacterBody3D или AnimatableBody3D; только обычный Carry
## требует RigidBody3D и проверяется через within_pickup_reach_body().
static func within_pickup_reach(holder: Entity, target: Entity) -> bool:
	if not GrabQueries.entity_available(target):
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
	var raycast: RayCast3D = GrabQueries.interaction_raycast(holder)
	if control == null or interactor == null or not is_instance_valid(raycast):
		return false
	if InteractionTargetingGeometry.find_target(holder, interactor) != target:
		return false
	if not raycast.is_colliding():
		return false

	var hit_distance: float = raycast.global_position.distance_to(raycast.get_collision_point())
	return hit_distance <= maxf(control.pickup_distance, 0.0)


## Повторно проверяет первое физическое тело под лучом и дистанцию подбора.
static func within_pickup_reach_body(holder: Entity, body: RigidBody3D) -> bool:
	if not is_instance_valid(holder) or not is_instance_valid(body):
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
	var raycast: RayCast3D = GrabQueries.interaction_raycast(holder)
	if control == null or interactor == null or not is_instance_valid(raycast):
		return false
	if InteractionTargetingGeometry.find_physics_target(holder, interactor) != body:
		return false
	if not raycast.is_colliding():
		return false

	var hit_distance: float = raycast.global_position.distance_to(raycast.get_collision_point())
	return hit_distance <= maxf(control.pickup_distance, 0.0)
#endregion
