extends System
## Owns scheduled generic-body hold forces; E_GrabbableBody keeps its native physics callback.
class_name S_Grab

#region Scheduled generic physical holding
## Targeting precedes the hold step; captured interaction commands follow the physical cleanup flush.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_InteractionTargeting], Runs.Before: [S_InteractionInput]}


## Physical holding depends on explicit grab/load contracts, independently of player input.
func query() -> QueryBuilder:
	return q.with_all([C_GrabControl, C_CarryLoad])


## Traverses actual held slots and applies the common solver; structural retirement is queued.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return

	for holder: Entity in entities:
		_integrate_generic_bodies(holder, delta)


func _integrate_generic_bodies(holder: Entity, delta: float) -> void:
	for slot_index: int in 3:
		var held: Entity = GrabService.held_in_slot(holder, slot_index)
		if held == null:
			continue

		var body: RigidBody3D = GrabService.physical_body(held)
		if body == null or held is E_GrabbableBody:
			continue

		var grip: Relationship = GrabService.held_relationship(held)
		if grip == null or grip.target != holder:
			continue

		var grip_data: R_HeldBy = grip.relation as R_HeldBy
		if not grip_data.lifecycle_applied:
			continue

		var profile: GrabControlProfile = grip_data.profile
		var anchor: Node3D = GrabService.object_anchor(holder, held)
		if (
			not GrabService.holder_available(holder) or body.freeze or profile == null
			or not is_instance_valid(anchor)
		):
			cmd.add_custom(_release_invalid_grip.bind(holder, held, grip))
			continue

		var interactable: C_Interactable = held.get_component(C_Interactable) as C_Interactable
		if interactable != null and not interactable.enabled:
			cmd.add_custom(_release_invalid_grip.bind(holder, held, grip))
			continue

		var allowed_break_distance: float = GrabPhysicsSolver.allowed_break_distance(
			holder,
			anchor,
			grip_data,
			profile,
		)
		if not GrabPhysicsSolver.integrate_body(
			body,
			delta,
			anchor,
			grip_data,
			profile,
			allowed_break_distance,
		):
			cmd.add_custom(_release_invalid_grip.bind(holder, held, grip))


func _release_invalid_grip(holder: Entity, held: Entity, grip: Relationship) -> void:
	# A queued invalid grip cannot retire a replacement binding created before flush.
	if not EntityAvailability.contains(held, _world) or GrabService.held_relationship(held) != grip:
		return
	if grip.target == holder:
		GrabService.release(holder, held, false)
#endregion
