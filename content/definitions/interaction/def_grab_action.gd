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
	if not GrabService.holder_available(actor):
		return false
	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if focus >= InteractionControlFocus.Priority.PUSH:
		return false

	if kind == Kind.PICKUP:
		if is_instance_valid(physical_body):
			return GrabService.can_pickup_body(
				actor,
				physical_body,
				hold_slot,
				replace_occupant,
				source,
			)
		return (
			GrabService.entity_available(source)
			and GrabService.can_pickup(actor, source, hold_slot, replace_occupant)
		)

	if not GrabService.entity_available(source):
		return false
	var grip: Relationship = GrabService.held_relationship(source)
	if grip == null or grip.target != actor:
		return false
	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	if (
		grip_data.slot != C_Grabbable.HoldSlot.CARRY
		and focus != InteractionControlFocus.Priority.HANDS
	):
		return false
	var profile: GrabControlProfile = (
		grip_data.profile if grip_data.profile != null else GrabService.profile_for(source)
	)
	return kind != Kind.ROTATE or profile.manual_rotation_enabled


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	if not is_available(actor, source, _target):
		return
	match kind:
		Kind.PICKUP:
			if is_instance_valid(physical_body):
				GrabService.try_pickup_body(actor, physical_body, hold_slot, replace_occupant)
			else:
				GrabService.try_pickup(actor, source, hold_slot, replace_occupant)
		Kind.RELEASE:
			GrabService.release(actor, source)
		Kind.THROW:
			GrabService.throw(actor, source)
		Kind.ROTATE:
			var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
			var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
			var grip: Relationship = GrabService.held_relationship(source)
			if control == null or controller == null or grip == null:
				return
			control.rotation_active = true
			var grip_data: R_HeldBy = grip.relation as R_HeldBy
			var profile: GrabControlProfile = (
				grip_data.profile if grip_data.profile != null else GrabService.profile_for(source)
			)
			var carry_load: C_CarryLoad = actor.get_component(C_CarryLoad) as C_CarryLoad
			var strength: C_Strength = actor.get_component(C_Strength) as C_Strength
			var mobility_multiplier: float = CarryLoadPolicy.active_multiplier(
				carry_load,
				strength,
			)
			grip_data.rotation_offset = GrabService.rotated_offset(
				grip_data.rotation_offset,
				controller.look_delta * mobility_multiplier,
				profile.rotation_axis,
			)
