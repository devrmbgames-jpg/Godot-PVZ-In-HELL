extends RefCounted
class_name InteractionControlFocus

enum Priority {
	HANDS,
	CARRY,
	PUSH,
	MODAL,
}


static func acquire(actor: Entity, owner: Object, priority: Priority) -> int:
	var control: C_GrabControl = _control(actor)
	if control != null and is_instance_valid(owner):
		var capture: InteractionControlCapture = InteractionControlCapture.new()
		capture.owner = weakref(owner)
		capture.priority = priority
		var token: int = capture.get_instance_id()
		control.captures[token] = capture
		control.rotation_active = false
		return token
	return 0


static func release(actor: Entity, token: int) -> void:
	var control: C_GrabControl = _control(actor)
	if control != null:
		control.captures.erase(token)


static func current(actor: Entity) -> Priority:
	var control: C_GrabControl = _control(actor)
	var priority: int = Priority.HANDS
	if control != null:
		for token: int in control.captures.keys():
			var capture: InteractionControlCapture = control.captures[token]
			if capture.owner.get_ref() == null:
				control.captures.erase(token)
			else:
				priority = maxi(priority, capture.priority)
	return priority as Priority


static func _control(actor: Entity) -> C_GrabControl:
	return actor.get_component(C_GrabControl) as C_GrabControl if is_instance_valid(actor) else null
