extends RefCounted
## Освобождает живую связь хвата и однократно очищает её физические, input и cache эффекты.
class_name GrabReleaseService

#region Operations
## Удаляет соответствующую связь и её эффекты, сохраняя физическую инерцию тела.
static func release(holder: Entity, held: Entity, notify_player: bool = true) -> void:
	if not is_instance_valid(held):
		return

	var grip: Relationship = GrabQueries.held_relationship(held)
	if grip != null and grip.target == holder:
		var grip_data: R_HeldBy = grip.relation as R_HeldBy
		var notify: bool = (
			notify_player and grip_data.lifecycle_applied
			and GrabQueries.holder_available(holder) and GrabQueries.entity_available(held)
		)
		held.remove_relationship(grip)
		# World отключает сигналы сущности до уведомления наблюдателей жизненного цикла.
		# Идемпотентная очистка покрывает и этот путь удаления.
		grip_removed(held, grip)
		if notify and held.has_component(C_Package):
			PlayerInteractionEvents.publish(holder, held, PlayerInteractionEvent.Kind.PARCEL_PLACED)


## Однократно восстанавливает столкновения и сон, освобождает захват и кеш слота.
static func grip_removed(held: Entity, grip: Relationship) -> void:
	var marker: C_Marker = held.get_component(C_Marker) as C_Marker
	if marker != null:
		MarkerSessionCleanup.end(held, grip.target as Entity)

	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	if not grip_data.lifecycle_applied:
		return

	grip_data.lifecycle_applied = false
	if is_instance_valid(held) and held.has_component(C_MeleeWeapon):
		MeleeWeaponPresentation.reset(held)
	var holder: Entity = grip.target as Entity if is_instance_valid(grip.target) else null
	var body: RigidBody3D = GrabQueries.physical_body(held)
	if is_instance_valid(holder):
		InteractionControlFocus.release(holder, grip_data.capture_token)
		var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
		if control != null and GrabHoldCache.cached(control, grip_data.slot) == held:
			GrabHoldCache.reset_holder(holder, grip_data.slot)

	var cleanup: Callable = release.bind(holder, held, false)
	if is_instance_valid(held) and held.tree_exiting.is_connected(cleanup):
		held.tree_exiting.disconnect(cleanup)

	if is_instance_valid(holder) and holder.tree_exiting.is_connected(cleanup):
		holder.tree_exiting.disconnect(cleanup)

	if body != null:
		if grip_data.added_collision_exception and is_instance_valid(holder):
			var holder_body: PhysicsBody3D = holder as Node as PhysicsBody3D
			if holder_body != null:
				body.remove_collision_exception_with(holder_body)
		body.can_sleep = grip_data.previous_can_sleep


## Освобождает все входящие и исходящие связи удержания недоступной сущности.
static func entity_unavailable(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return

	var grip: Relationship = GrabQueries.held_relationship(entity)
	if grip != null:
		entity.remove_relationship(grip)
		grip_removed(entity, grip)

	for slot_index: int in 3:
		var held: Entity = GrabQueries.held_in_slot(entity, slot_index)
		if held != null:
			release(entity, held, false)
#endregion
