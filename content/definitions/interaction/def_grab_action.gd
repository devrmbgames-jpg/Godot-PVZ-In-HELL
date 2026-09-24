extends DEF_InteractionAction
## Executes validated pickup, release, throw and rotation commands.
class_name DEF_GrabAction

enum Kind {
	PICKUP,
	RELEASE,
	THROW,
	ROTATE,
}

var kind: Kind = Kind.PICKUP
var hold_slot: int = -1
var replace_occupant: bool = false
## Raw physics target for generic Carry. A GECS handle is created only on execute.
var physical_body: RigidBody3D = null


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if not S_Grab.holder_available(actor):
		return false
	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if focus >= InteractionControlFocus.Priority.PUSH:
		return false

	if kind == Kind.PICKUP:
		if is_instance_valid(physical_body):
			return S_Grab.can_pickup_body(
				actor,
				physical_body,
				hold_slot,
				replace_occupant,
				source,
			)
		return (
			S_Grab.entity_available(source)
			and S_Grab.can_pickup(actor, source, hold_slot, replace_occupant)
		)

	if not S_Grab.entity_available(source):
		return false
	var grip: Relationship = S_Grab.held_relationship(source)
	if grip == null or grip.target != actor:
		return false
	var grip_data: C_HeldBy = grip.relation as C_HeldBy
	if (
		grip_data.slot != C_Grabbable.HoldSlot.CARRY
		and focus != InteractionControlFocus.Priority.HANDS
	):
		return false
	var profile: GrabControlProfile = (
		grip_data.profile if grip_data.profile != null else S_Grab.profile_for(source)
	)
	return kind != Kind.ROTATE or profile.manual_rotation_enabled


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	if not is_available(actor, source, _target):
		return
	match kind:
		Kind.PICKUP:
			if is_instance_valid(physical_body):
				S_Grab.try_pickup_body(actor, physical_body, hold_slot, replace_occupant)
			else:
				S_Grab.try_pickup(actor, source, hold_slot, replace_occupant)
		Kind.RELEASE:
			S_Grab.release(actor, source)
		Kind.THROW:
			S_Grab.throw(actor, source)
		Kind.ROTATE:
			var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
			var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
			var grip: Relationship = S_Grab.held_relationship(source)
			if control == null or controller == null or grip == null:
				return
			control.rotation_active = true
			var grip_data: C_HeldBy = grip.relation as C_HeldBy
			var profile: GrabControlProfile = (
				grip_data.profile if grip_data.profile != null else S_Grab.profile_for(source)
			)
			var carry_load: C_CarryLoad = actor.get_component(C_CarryLoad) as C_CarryLoad
			var strength: C_Strength = actor.get_component(C_Strength) as C_Strength
			var mobility_multiplier: float = CarryLoadPolicy.active_multiplier(
				carry_load,
				strength,
			)
			grip_data.rotation_offset = S_Grab.rotated_offset(
				grip_data.rotation_offset,
				controller.look_delta * mobility_multiplier,
				profile.rotation_axis,
			)
