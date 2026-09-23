extends RefCounted
## Arbitrates independent nested capture tokens without changing item ownership.
class_name InteractionControlFocus

enum Priority {
	HANDS,
	CARRY,
	PUSH,
	TRANSPORT,
	DRAWING,
	MODAL,
}


## Returns a distinct token, including for repeated captures by the same owner.
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


## Releases only the requested token; other capture owners retain their priority.
static func release(actor: Entity, token: int) -> void:
	var control: C_GrabControl = _control(actor)
	if control != null:
		control.captures.erase(token)


## Returns the highest live capture priority and prunes destroyed owners.
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
