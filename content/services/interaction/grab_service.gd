extends RefCounted
## Grab transactions, ownership lifecycle, slot queries and physics helpers.
class_name GrabService

#region Constants
const ROTATION_SENSITIVITY: float = 0.006
#endregion




#region Public API
## Releases invalid grips before routing the actor input tick.
static func handle_input(holder: Entity) -> void:
	if not is_instance_valid(holder):
		return

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var controller: C_Controller = holder.get_component(C_Controller) as C_Controller
	var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
	if control == null or controller == null or interactor == null:
		return

	for slot_index: int in 3:
		var held: Entity = held_in_slot(holder, slot_index)
		if held == null:
			continue
		var body: RigidBody3D = physical_body(held)
		var interactable: C_Interactable = held.get_component(C_Interactable) as C_Interactable
		if (
			not holder_available(holder) or not entity_available(held)
			or body == null or body.freeze
			or (interactable != null and not interactable.enabled)
		):
			release(holder, held)
	if not holder_available(holder):
		interactor.prompt_text = ""
		return

	InteractionActionResolver.handle_input(holder)


## Prevalidate the complete transaction before releasing an occupied hand.
static func can_pickup(
	holder: Entity,
	target: Entity,
	slot_index: int,
	replace: bool = false,
) -> bool:
	if not entity_available(target):
		return false
	var body: RigidBody3D = physical_body(target)
	return can_pickup_body(holder, body, slot_index, replace, target)


## Validates arbitrary rigid bodies without requiring GECS membership on the body itself.
static func can_pickup_body(
	holder: Entity,
	body: RigidBody3D,
	slot_index: int,
	replace: bool = false,
	handle: Entity = null,
) -> bool:
	if not holder_available(holder) or not is_instance_valid(body):
		return false
	if body == (holder as Node as RigidBody3D) or slot_index < 0:
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if control == null or load_state == null or body.freeze:
		return false

	var resolved_handle: Entity = handle
	if resolved_handle == null:
		resolved_handle = PhysicsGrabTarget.handle_for(body, false)
	if resolved_handle != null:
		if not entity_available(resolved_handle) or held_relationship(resolved_handle) != null:
			return false
		var interactable: C_Interactable = (
			resolved_handle.get_component(C_Interactable) as C_Interactable
		)
		if interactable != null and not interactable.enabled:
			return false

	var profile: GrabControlProfile = profile_for(resolved_handle)
	if not profile_slot_allowed(profile, slot_index):
		return false
	var strength: C_Strength = holder.get_component(C_Strength) as C_Strength
	if slot_index == C_Grabbable.HoldSlot.CARRY and not control.can_carry_body(body, strength):
		return false
	if not is_instance_valid(slot_anchor(holder, slot_index)):
		return false
	if held_in_slot(holder, slot_index) != null and not replace:
		return false
	return within_pickup_reach_body(holder, body)


## Atomically validates and acquires the selected slot, optionally replacing its occupant.
static func try_pickup(
	holder: Entity,
	target: Entity,
	slot_index: int = -1,
	replace: bool = false,
) -> bool:
	if not entity_available(target):
		return false
	var body: RigidBody3D = physical_body(target)
	if body == null:
		return false
	if slot_index < 0:
		slot_index = pickup_slot_for_body(holder, body, false)
	if not can_pickup(holder, target, slot_index, replace):
		return false

	ThrowContext.cancel(target)
	CartCargoService.release(target)
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var anchor: Node3D = slot_anchor(holder, slot_index)
	var profile: GrabControlProfile = profile_for(target)
	var grip_data: R_HeldBy = R_HeldBy.new()
	grip_data.slot = slot_index as C_Grabbable.HoldSlot
	grip_data.profile = profile
	if slot_index == C_Grabbable.HoldSlot.CARRY:
		grip_data.hold_distance = carry_distance_profile(control, profile)
	if not profile.reset_rotation_on_pickup:
		grip_data.rotation_offset = (
			anchor.global_basis.orthonormalized().get_rotation_quaternion().inverse()
			* body.global_basis.orthonormalized().get_rotation_quaternion()
		).normalized()

	var occupant: Entity = held_in_slot(holder, slot_index)
	if occupant != null:
		release(holder, occupant)
	target.add_relationship(Relationship.new(grip_data, holder))
	return held_in_slot(holder, slot_index) == target


## Creates a lightweight GECS handle only when a raw body is actually picked up.
static func try_pickup_body(
	holder: Entity,
	body: RigidBody3D,
	slot_index: int = -1,
	replace: bool = false,
) -> bool:
	if slot_index < 0:
		slot_index = pickup_slot_for_body(holder, body, false)
	var existing: Entity = PhysicsGrabTarget.handle_for(body, false)
	if not can_pickup_body(holder, body, slot_index, replace, existing):
		return false
	var handle: Entity = PhysicsGrabTarget.handle_for(body, true)
	if handle == null:
		return false
	return try_pickup(holder, handle, slot_index, replace)


## Removes matching ownership and side effects while preserving physical inertia.
static func release(holder: Entity, held: Entity) -> void:
	if not is_instance_valid(held):
		return
	var grip: Relationship = held_relationship(held)
	if grip != null and grip.target == holder:
		held.remove_relationship(grip)
		# World removal disconnects entity signals before notifying lifecycle listeners.
		# Cleanup is idempotent, so it also covers this teardown path.
		grip_removed(held, grip)


## Releases matching ownership before applying the configured velocity-change impulse.
static func throw(holder: Entity, held: Entity) -> void:
	if not is_instance_valid(holder) or not is_instance_valid(held):
		return

	var grip: Relationship = held_relationship(held)
	if grip == null or grip.target != holder:
		return

	var controller: C_Controller = holder.get_component(C_Controller) as C_Controller
	var body: RigidBody3D = physical_body(held)
	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	var profile: GrabControlProfile = _grip_profile(held, grip_data)

	if controller == null or body == null or profile == null:
		release(holder, held)
		return

	var carry_load: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	var strength: C_Strength = holder.get_component(C_Strength) as C_Strength
	var effective_throw_velocity: float = CarryLoadPolicy.scaled_value(
		profile.throw_velocity,
		carry_load,
		strength,
	)
	var impulse: Vector3 = throw_impulse(
		controller.direction_look,
		effective_throw_velocity,
		body.mass,
	)

	release(holder, held)
	body.sleeping = false
	body.apply_central_impulse(impulse)
	if not impulse.is_zero_approx():
		ThrowContext.arm(held, holder)


## Drives a held body toward its relation-selected anchor on the physics step.
static func integrate_forces(entity: Entity, state: PhysicsDirectBodyState3D) -> void:
	var grip: Relationship = held_relationship(entity)
	if grip == null:
		return

	var holder: Entity = grip.target as Entity
	var body: RigidBody3D = physical_body(entity)
	var anchor: Node3D = object_anchor(holder, entity)
	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	var profile: GrabControlProfile = _grip_profile(entity, grip_data)
	if (
		not holder_available(holder) or not entity_available(entity)
		or body == null or body.freeze or profile == null or not is_instance_valid(anchor)
	):
		release(holder, entity)
		return

	var interactable: C_Interactable = entity.get_component(C_Interactable) as C_Interactable
	if interactable != null and not interactable.enabled:
		release(holder, entity)
		return

	var allowed_break_distance: float = _allowed_break_distance(
		holder,
		anchor,
		grip_data,
		profile,
	)
	if not GrabPhysicsSolver.integrate_state(
		state,
		anchor,
		grip_data,
		profile,
		allowed_break_distance,
	):
		release(holder, entity)

#endregion


#region Lifecycle transitions
## Called by O_GrabLifecycle for any relationship producer, not just try_pickup.
static func grip_added(held: Entity, grip: Relationship) -> bool:
	var holder: Entity = grip.target as Entity
	var body: RigidBody3D = physical_body(held)
	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	var profile: GrabControlProfile = _grip_profile(held, grip_data)
	var is_invalid: bool = (
		not holder_available(holder) or not entity_available(held) or body == null
		or body.freeze or profile == null or not is_instance_valid(object_anchor(holder, held))
	)
	if is_invalid:
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if control == null or load_state == null:
		return false
	var strength: C_Strength = holder.get_component(C_Strength) as C_Strength
	if grip_data.slot == C_Grabbable.HoldSlot.CARRY and not control.can_carry_body(body, strength):
		return false
	if (
		held_relationship(held) != grip or not profile_slot_allowed(profile, grip_data.slot)
		or held_in_slot(holder, grip_data.slot) != null
	):
		return false

	grip_data.lifecycle_applied = true
	if grip_data.slot == C_Grabbable.HoldSlot.CARRY and grip_data.hold_distance <= 0.0:
		grip_data.hold_distance = carry_distance_profile(control, profile)
	grip_data.previous_can_sleep = body.can_sleep

	body.can_sleep = false
	body.sleeping = false

	var holder_body: PhysicsBody3D = holder as Node as PhysicsBody3D
	if holder_body != null and not body.get_collision_exceptions().has(holder_body):
		body.add_collision_exception_with(holder_body)
		grip_data.added_collision_exception = true

	_set_cached(control, grip_data.slot, held)
	if grip_data.slot == C_Grabbable.HoldSlot.CARRY:
		grip_data.capture_token = InteractionControlFocus.acquire(
			holder,
			held,
			InteractionControlFocus.Priority.CARRY,
		)
		load_state.active = true
		load_state.mass_kg = body.mass

	var cleanup: Callable = release.bind(holder, held)
	if not held.tree_exiting.is_connected(cleanup):
		held.tree_exiting.connect(cleanup)
	if not holder.tree_exiting.is_connected(cleanup):
		holder.tree_exiting.connect(cleanup)

	return true


## Idempotently restores collision, sleep, capture and slot-cache state.
static func grip_removed(held: Entity, grip: Relationship) -> void:
	var marker: C_Marker = held.get_component(C_Marker) as C_Marker
	if marker != null:
		S_Marker.end(held, grip.target as Entity)

	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	if not grip_data.lifecycle_applied:
		return

	grip_data.lifecycle_applied = false
	var holder: Entity = grip.target as Entity if is_instance_valid(grip.target) else null
	var body: RigidBody3D = physical_body(held)
	if is_instance_valid(holder):
		InteractionControlFocus.release(holder, grip_data.capture_token)
		var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
		if control != null and _cached(control, grip_data.slot) == held:
			reset_holder(holder, grip_data.slot)

	var cleanup: Callable = release.bind(holder, held)
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


## Releases all incoming and outgoing held relationships for an unavailable entity.
static func entity_unavailable(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return

	var grip: Relationship = held_relationship(entity)
	if grip != null:
		entity.remove_relationship(grip)
		grip_removed(entity, grip)

	for slot_index: int in 3:
		var held: Entity = held_in_slot(entity, slot_index)
		if held != null:
			release(entity, held)


## Clears one derived cache and its Carry modifiers without creating ownership.
static func reset_holder(holder: Entity, slot_index: int = C_Grabbable.HoldSlot.CARRY) -> void:
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	if control != null:
		var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
		if interactor != null and interactor.target == _cached(control, slot_index):
			interactor.target = null
		_set_cached(control, slot_index, null)
		control.rotation_active = false

	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if load_state != null and slot_index == C_Grabbable.HoldSlot.CARRY:
		load_state.active = false
		load_state.mass_kg = 0.0

#endregion


#region Position and rotation math
## Returns a mass-aware bounded spring force with gravity compensation.
static func position_force(
	position_error: Vector3,
	velocity_error: Vector3,
	gravity: Vector3,
	body_mass: float,
	config: C_Grabbable,
) -> Vector3:
	return GrabPhysicsSolver.position_force(
		position_error,
		velocity_error,
		gravity,
		body_mass,
		GrabControlProfile.from_grabbable(config),
	)


## Returns a bounded shortest-arc angular velocity without residual spring momentum.
static func rotation_velocity(
	current: Quaternion,
	desired: Quaternion,
	step: float,
	config: C_Grabbable,
) -> Vector3:
	return GrabPhysicsSolver.rotation_velocity(
		current,
		desired,
		step,
		GrabControlProfile.from_grabbable(config),
	)


## Applies manual input within the configured rotation-axis policy.
static func rotated_offset(
	offset: Quaternion,
	look_delta: Vector2,
	axis: C_Grabbable.RotationAxis = C_Grabbable.RotationAxis.FREE,
) -> Quaternion:
	if axis == C_Grabbable.RotationAxis.Y_ONLY:
		return Quaternion(Vector3.UP, offset.get_euler().y - look_delta.x * ROTATION_SENSITIVITY)
	return (
		Quaternion(Vector3.UP, -look_delta.x * ROTATION_SENSITIVITY)
		* Quaternion(Vector3.RIGHT, -look_delta.y * ROTATION_SENSITIVITY) * offset
	).normalized()


## Converts a configured velocity change into a mass-scaled impulse.
static func throw_impulse(direction: Vector3, velocity_change: float, body_mass: float) -> Vector3:
	return direction.normalized() * maxf(velocity_change, 0.0) * body_mass
#endregion


#region Queries and validation
## Finds the authoritative held relationship directly on an entity.
static func held_relationship(entity: Entity) -> Relationship:
	if not is_instance_valid(entity):
		return null

	# Read the authoritative local relationships without allocating query patterns.
	for grip: Relationship in entity.relationships:
		if grip.relation is R_HeldBy:
			return grip

	return null


## Compatibility query for single-object callers; never use for capacity/ownership.
static func held_object(holder: Entity) -> Entity:
	for slot_index: int in 3:
		var held: Entity = held_in_slot(holder, slot_index)
		if held != null:
			return held
	return null


## Returns a cached occupant only when its authoritative relation matches the slot.
static func held_in_slot(holder: Entity, slot_index: int) -> Entity:
	if not is_instance_valid(holder):
		return null
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	if control == null:
		return null
	var held: Entity = _cached(control, slot_index)
	if is_instance_valid(held):
		var grip: Relationship = held_relationship(held)
		if grip != null and grip.target == holder:
			if (grip.relation as R_HeldBy).slot == slot_index:
				return held
	if held != null:
		reset_holder(holder, slot_index)
	return null


static func _cached(control: C_GrabControl, slot_index: int) -> Entity:
	match slot_index:
		C_Grabbable.HoldSlot.CARRY:
			return control.held_carry
		C_Grabbable.HoldSlot.RIGHT_HAND:
			return control.held_right
		C_Grabbable.HoldSlot.LEFT_HAND:
			return control.held_left
	return null


static func _set_cached(control: C_GrabControl, slot_index: int, held: Entity) -> void:
	match slot_index:
		C_Grabbable.HoldSlot.CARRY:
			control.held_carry = held
		C_Grabbable.HoldSlot.RIGHT_HAND:
			control.held_right = held
		C_Grabbable.HoldSlot.LEFT_HAND:
			control.held_left = held


## Checks whether an authored prop supports the requested Carry or hand slot.
static func slot_allowed(config: C_Grabbable, slot_index: int) -> bool:
	return profile_slot_allowed(GrabControlProfile.from_grabbable(config), slot_index)


static func profile_slot_allowed(profile: GrabControlProfile, slot_index: int) -> bool:
	if profile == null:
		return false
	if slot_index == C_Grabbable.HoldSlot.CARRY:
		return profile.allowed_hand_slots == 0
	return (
		slot_index in [C_Grabbable.HoldSlot.RIGHT_HAND, C_Grabbable.HoldSlot.LEFT_HAND]
		and (profile.allowed_hand_slots & (1 << slot_index)) != 0
	)


## Maps primary or secondary controls to a physical hand, respecting the swap option.
static func mapped_hand(holder: Entity, secondary: bool = false) -> int:
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	if secondary != (control != null and control.swap_hand_controls):
		return C_Grabbable.HoldSlot.LEFT_HAND
	return C_Grabbable.HoldSlot.RIGHT_HAND


## Selects the E/F hand according to free slots, replacement role and allowed hands.
static func pickup_slot(holder: Entity, target: Entity, replacement_button: bool) -> int:
	if not is_instance_valid(target) or not is_instance_valid(holder):
		return -1
	var config: C_Grabbable = target.get_component(C_Grabbable) as C_Grabbable
	if config == null:
		return -1
	if config.allowed_hand_slots == 0:
		return C_Grabbable.HoldSlot.CARRY if not replacement_button else -1
	var primary: int = mapped_hand(holder)
	var secondary: int = mapped_hand(holder, true)
	var primary_busy: bool = held_in_slot(holder, primary) != null
	var secondary_busy: bool = held_in_slot(holder, secondary) != null
	var selected: int = primary
	if replacement_button:
		if not primary_busy and not secondary_busy:
			return -1
		selected = secondary if secondary_busy else primary
	else:
		selected = secondary if primary_busy and not secondary_busy else primary
		if not primary_busy and not secondary_busy and not slot_allowed(config, selected):
			selected = secondary
	return selected if slot_allowed(config, selected) else -1


## Raw bodies are Carry-only; authored C_Grabbable keeps its hand-slot policy.
static func pickup_slot_for_body(
	holder: Entity,
	body: RigidBody3D,
	replacement_button: bool,
) -> int:
	if not is_instance_valid(holder) or not is_instance_valid(body):
		return -1
	var handle: Entity = PhysicsGrabTarget.handle_for(body, false)
	if handle != null and (handle.get_component(C_Grabbable) as C_Grabbable) != null:
		return pickup_slot(holder, handle, replacement_button)
	return C_Grabbable.HoldSlot.CARRY if not replacement_button else -1


## Returns the holder-owned LOS ray used by targeting and pickup validation.
static func interaction_raycast(holder: Entity) -> RayCast3D:
	if not is_instance_valid(holder):
		return null

	return holder.get("interaction_ray_cast") as RayCast3D


## Returns the authored Carry anchor owned by the holder entity.
static func hold_anchor(holder: Entity) -> Node3D:
	if not is_instance_valid(holder):
		return null

	return holder.get("hold_anchor") as Node3D


## Resolves an item anchor from its runtime relationship or proposed pickup slot.
static func object_anchor(holder: Entity, target: Entity) -> Node3D:
	if not is_instance_valid(holder) or not is_instance_valid(target):
		return null
	var grip: Relationship = held_relationship(target)
	var slot_index: int = (
		(grip.relation as R_HeldBy).slot
		if grip != null
		else pickup_slot(holder, target, false)
	)
	return slot_anchor(holder, slot_index)


## Selects the normal or suspended authored anchor for a physical slot.
static func slot_anchor(holder: Entity, slot_index: int) -> Node3D:
	if not is_instance_valid(holder):
		return null
	if (
		slot_index != C_Grabbable.HoldSlot.CARRY
		and InteractionControlFocus.current(holder) != InteractionControlFocus.Priority.HANDS
	):
		var right_hand: bool = slot_index == C_Grabbable.HoldSlot.RIGHT_HAND
		var lowered: Node3D = holder.get(
			"lowered_right_hand_slot" if right_hand else "lowered_left_hand_slot"
		) as Node3D
		if is_instance_valid(lowered):
			return lowered
	match slot_index:
		C_Grabbable.HoldSlot.CARRY:
			return hold_anchor(holder)
		C_Grabbable.HoldSlot.RIGHT_HAND:
			return holder.get("right_hand_slot") as Node3D
		C_Grabbable.HoldSlot.LEFT_HAND:
			return holder.get("left_hand_slot") as Node3D
	return null


## Revalidates first-hit LOS and the shared physical-interaction reach limit.
## Gameplay Entity targets may be CharacterBody3D/AnimatableBody3D; only generic Carry
## requires RigidBody3D and therefore uses within_pickup_reach_body().
static func within_pickup_reach(holder: Entity, target: Entity) -> bool:
	if not entity_available(target):
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
	var raycast: RayCast3D = interaction_raycast(holder)
	if control == null or interactor == null or not is_instance_valid(raycast):
		return false
	if InteractionTargetingService.find_target(holder, interactor) != target:
		return false
	if not raycast.is_colliding():
		return false

	var hit_distance: float = raycast.global_position.distance_to(raycast.get_collision_point())
	return hit_distance <= maxf(control.pickup_distance, 0.0)


static func within_pickup_reach_body(holder: Entity, body: RigidBody3D) -> bool:
	if not is_instance_valid(holder) or not is_instance_valid(body):
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
	var raycast: RayCast3D = interaction_raycast(holder)
	if control == null or interactor == null or not is_instance_valid(raycast):
		return false
	if InteractionTargetingService.find_physics_target(holder, interactor) != body:
		return false
	if not raycast.is_colliding():
		return false

	var hit_distance: float = raycast.global_position.distance_to(raycast.get_collision_point())
	return hit_distance <= maxf(control.pickup_distance, 0.0)


## Returns an item distance override or the holder default; hands have no extra offset.
static func carry_distance(control: C_GrabControl, config: C_Grabbable) -> float:
	return carry_distance_profile(control, GrabControlProfile.from_grabbable(config))


static func carry_distance_profile(
	control: C_GrabControl,
	profile: GrabControlProfile,
) -> float:
	if control == null or profile == null:
		return 0.0
	if profile.allowed_hand_slots != 0:
		return 0.0
	if profile.hold_distance >= 0.0:
		return profile.hold_distance
	return control.hold_distance


## Resolves the physical body behind either a normal Entity or a runtime proxy.
static func physical_body(handle: Entity) -> RigidBody3D:
	return PhysicsGrabTarget.body_for(handle)


## Creates an effective default/override profile without making C_Grabbable mandatory.
static func profile_for(handle: Entity) -> GrabControlProfile:
	var config: C_Grabbable = null
	if is_instance_valid(handle):
		config = handle.get_component(C_Grabbable) as C_Grabbable
	return GrabControlProfile.from_grabbable(config)


static func _grip_profile(handle: Entity, grip_data: R_HeldBy) -> GrabControlProfile:
	if grip_data == null:
		return null
	if grip_data.profile == null:
		grip_data.profile = profile_for(handle)
	return grip_data.profile


static func _allowed_break_distance(
	holder: Entity,
	anchor: Node3D,
	grip_data: R_HeldBy,
	profile: GrabControlProfile,
) -> float:
	var allowed: float = profile.break_distance
	var hand_suspended: bool = (
		grip_data.slot != C_Grabbable.HoldSlot.CARRY
		and InteractionControlFocus.current(holder) != InteractionControlFocus.Priority.HANDS
	)
	if not hand_suspended:
		return allowed
	var hand_property: StringName = &"right_hand_slot"
	if grip_data.slot == C_Grabbable.HoldSlot.LEFT_HAND:
		hand_property = &"left_hand_slot"
	var normal_anchor: Node3D = holder.get(hand_property) as Node3D
	if is_instance_valid(normal_anchor):
		allowed += normal_anchor.global_position.distance_to(anchor.global_position)
	return allowed


## Bodies that already call integrate_forces keep the exact callback solver.
## Other rigid bodies use the same spring profile from the holder System before physics.
static func integrate_generic_bodies(holder: Entity, delta: float) -> void:
	if delta <= 0.0:
		return
	for slot_index: int in 3:
		var held: Entity = held_in_slot(holder, slot_index)
		if held == null:
			continue
		var body: RigidBody3D = physical_body(held)
		if body == null or held is E_GrabbableBody:
			continue
		var grip: Relationship = held_relationship(held)
		if grip == null or grip.target != holder:
			continue
		var grip_data: R_HeldBy = grip.relation as R_HeldBy
		var profile: GrabControlProfile = _grip_profile(held, grip_data)
		var anchor: Node3D = object_anchor(holder, held)
		if (
			not holder_available(holder) or body.freeze or profile == null
			or not is_instance_valid(anchor)
		):
			release(holder, held)
			continue
		var interactable: C_Interactable = held.get_component(C_Interactable) as C_Interactable
		if interactable != null and not interactable.enabled:
			release(holder, held)
			continue
		var allowed_break_distance: float = _allowed_break_distance(
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
			release(holder, held)


## Checks live tree and World membership before gameplay mutation.
static func entity_available(entity: Entity) -> bool:
	return (
		is_instance_valid(entity) and not entity.is_queued_for_deletion()
		and entity.is_inside_tree() and entity.enabled and is_instance_valid(ECS.world)
		and ECS.world.entity_to_archetype.has(entity)
	)


## Also rejects disabled motion control and defeated holders.
static func holder_available(holder: Entity) -> bool:
	if not entity_available(holder):
		return false

	var motion: C_Motion = holder.get_component(C_Motion) as C_Motion
	var health: C_Health = holder.get_component(C_Health) as C_Health
	return (motion == null or motion.control_enabled) and (health == null or health.current > 0.0)
#endregion
