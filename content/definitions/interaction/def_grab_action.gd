extends InteractionAction
class_name GrabAction

enum Kind {
	PICKUP,
	RELEASE,
	THROW,
	ROTATE,
}

var kind: Kind = Kind.PICKUP
var hold_slot: int = -1
var replace_occupant: bool = false


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if not S_Grab.holder_available(actor) or not S_Grab.entity_available(source):
		return false
	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if focus >= InteractionControlFocus.Priority.PUSH:
		return false
	if kind != Kind.PICKUP:
		var grip: Relationship = S_Grab.held_relationship(source)
		if grip == null or grip.target != actor:
			return false
		if (
			(grip.relation as C_HeldBy).slot != C_Grabbable.HoldSlot.CARRY
			and focus != InteractionControlFocus.Priority.HANDS
		):
			return false
		var config: C_Grabbable = source.get_component(C_Grabbable) as C_Grabbable
		return kind != Kind.ROTATE or (config != null and config.manual_rotation_enabled)
	return S_Grab.can_pickup(actor, source, hold_slot, replace_occupant)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	if not is_available(actor, source, _target):
		return
	match kind:
		Kind.PICKUP:
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
			var config: C_Grabbable = source.get_component(C_Grabbable) as C_Grabbable
			grip_data.rotation_offset = S_Grab.rotated_offset(
				grip_data.rotation_offset,
				controller.look_delta,
				config.rotation_axis,
			)
