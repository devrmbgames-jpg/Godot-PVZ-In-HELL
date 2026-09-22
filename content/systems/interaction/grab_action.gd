extends InteractionAction
class_name GrabAction

enum Kind {
	PICKUP,
	RELEASE,
	THROW,
	ROTATE,
}

var kind: Kind = Kind.PICKUP


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if not S_Grab.holder_available(actor) or not S_Grab.entity_available(source):
		return false
	var held: Entity = S_Grab.held_object(actor)
	if kind != Kind.PICKUP:
		if held != source:
			return false
		var config: C_Grabbable = source.get_component(C_Grabbable) as C_Grabbable
		return kind != Kind.ROTATE or (config != null and config.manual_rotation_enabled)
	var body: RigidBody3D = source as Node as RigidBody3D
	var interactable: C_Interactable = source.get_component(C_Interactable) as C_Interactable
	return (
		held == null and body != null and not body.freeze and source.has_component(C_Grabbable)
		and S_Grab.held_relationship(source) == null and interactable != null
		and interactable.enabled and is_instance_valid(S_Grab.object_anchor(actor, source))
		and S_Grab.within_pickup_reach(actor, source)
		and actor.has_component(C_CarryLoad) and actor.has_component(C_GrabControl)
	)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	match kind:
		Kind.PICKUP:
			S_Grab.try_pickup(actor, source)
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
